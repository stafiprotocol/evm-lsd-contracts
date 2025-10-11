// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../base/Ownable.sol";
import "./interfaces/IMonadStakePool.sol";
import "./interfaces/IMonadStaking.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, IMonadStakePool {
    // Custom errors to provide more descriptive revert messages.
    error AmountZero();
    error FailedToWithdrawForStaker();
    error FailedDelegate();
    error FailedUndelegate();
    error FailedCompound();
    error FailedWithdraw();
    error DuplicateWithdrawalId();
    error NotEnoughAmountToUndelegate();
    error NotEnoughRedelegateFee();

    event Delegate(uint64 validator, uint256 amount);
    event Undelegate(uint64 validator, uint256 amount);
    event WithdrawForStaker(address staker, uint256 amount);
    event ClaimUndelegated(uint64 validator, uint64 withdrawId);

    using EnumerableSet for EnumerableSet.UintSet;

    IMonadStaking public constant MONAD_STAKIING = IMonadStaking(0x0000000000000000000000000000000000001000);
    uint64 public constant WITHDRAWAL_DELAY = 1;

    address public stakeManagerAddress;
    uint256 public lastUndelegateIndex;

    mapping(uint64 => EnumerableSet.UintSet) _pendingWithdrawals;
    mapping(uint64 => uint8) _nextWithdrawId;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert CallerNotAllowed();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeManagerAddress, address _owner) external initializer {
        if (_stakeManagerAddress == address(0) || _owner == address(0)) revert AddressNotAllowed();

        _transferOwnership(_owner);
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getPendingWithdrawals(uint64 _validator) public view returns (uint8[] memory withdrawals) {
        uint256[] memory vals256 = _pendingWithdrawals[_validator].values();
        withdrawals = new uint8[](vals256.length);

        for (uint256 i = 0; i < vals256.length; i++) {
            withdrawals[i] = uint8(vals256[i]);
        }
    }

    function getDelegated(uint64 _validator) public view override returns (uint256) {
        (uint256 stake,,, uint256 deltaStake, uint256 nextDeltaStake,,) =
            MONAD_STAKIING.getDelegator(_validator, address(this));
        return stake + deltaStake + nextDeltaStake;
    }

    function getActived(uint64 _validator) public view returns (uint256) {
        (uint256 stake,,,,,,) = MONAD_STAKIING.getDelegator(_validator, address(this));
        return stake;
    }

    function getTotalDelegated(uint64[] calldata _validators) external view override returns (uint256) {
        uint256 totalAmount;
        for (uint256 i = 0; i < _validators.length; ++i) {
            totalAmount += getDelegated(_validators[i]);
        }
        return totalAmount;
    }

    // ------------ stakeManager ------------

    function delegateMulti(uint64[] memory _validators, uint256 _amount) external override onlyStakeManager {
        if (_amount == 0) {
            revert AmountZero();
        }
        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

        uint256 averageAmount = _amount / _validators.length;
        if (averageAmount == 0) {
            _govDelegate(_validators[0], _amount);

            return;
        }

        uint256 tail = _amount % _validators.length;
        for (uint256 i = 0; i < _validators.length; ++i) {
            uint256 amount = i == 0 ? averageAmount + tail : averageAmount;

            _govDelegate(_validators[i], amount);
        }
    }

    function undelegateMulti(uint64[] memory _validators, uint256 _amount) external override onlyStakeManager {
        if (_amount == 0) {
            revert AmountZero();
        }
        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

        uint256 needUndelegate = _amount;

        uint256 totalCycle = 0;
        for (
            uint256 i = (lastUndelegateIndex + 1) % _validators.length;
            totalCycle < _validators.length;
            (i = (i + 1) % _validators.length, ++totalCycle)
        ) {
            if (needUndelegate == 0) {
                break;
            }

            uint256 govDelegated = getActived(_validators[i]);

            uint256 willUndelegate = needUndelegate < govDelegated ? needUndelegate : govDelegated;

            _govUndelegate(_validators[i], willUndelegate);
            needUndelegate -= willUndelegate;

            lastUndelegateIndex = i;
        }

        if (needUndelegate > 0) {
            revert NotEnoughAmountToUndelegate();
        }
    }

    function withdrawMulti(uint64[] memory _validators) external override onlyStakeManager {
        for (uint256 i = 0; i < _validators.length; ++i) {
            _govWithdraw(_validators[i]);
        }
    }

    function compoundMulti(uint64[] memory _validators) external override onlyStakeManager {
        for (uint256 i = 0; i < _validators.length; ++i) {
            _govCompound(_validators[i]);
        }
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_staker == address(0)) revert AddressNotAllowed();
        if (_amount > 0) {
            (bool result,) = _staker.call{value: _amount}("");
            if (!result) revert FailedToWithdrawForStaker();

            emit WithdrawForStaker(_staker, _amount);
        }
    }

    function _govDelegate(uint64 _validator, uint256 _amount) internal {
        bool success = MONAD_STAKIING.delegate{value: _amount}(_validator);
        if (!success) revert FailedDelegate();

        emit Delegate(_validator, _amount);
    }

    function _govUndelegate(uint64 _validator, uint256 _amount) internal {
        uint8 withdrawId = _nextWithdrawId[_validator];

        if (withdrawId < 255) {
            _nextWithdrawId[_validator] = withdrawId + 1;
        } else {
            _nextWithdrawId[_validator] = 0;
        }

        if (!_pendingWithdrawals[_validator].add(uint256(withdrawId))) revert DuplicateWithdrawalId();

        bool success = MONAD_STAKIING.undelegate(_validator, _amount, withdrawId);
        if (!success) revert FailedUndelegate();

        emit Undelegate(_validator, _amount);
    }

    function _govWithdraw(uint64 _validator) internal {
        uint8[] memory withdrawals = getPendingWithdrawals(_validator);
        (uint64 epoch,) = MONAD_STAKIING.getEpoch();
        for (uint256 i = 0; i < withdrawals.length; i++) {
            (,, uint64 withdrawEpoch) = MONAD_STAKIING.getWithdrawalRequest(_validator, address(this), withdrawals[i]);
            if (withdrawEpoch + 2 + WITHDRAWAL_DELAY >= epoch) {
                bool success = MONAD_STAKIING.withdraw(_validator, withdrawals[i]);
                if (!success) revert FailedWithdraw();

                _pendingWithdrawals[_validator].remove(withdrawals[i]);
                emit ClaimUndelegated(_validator, withdrawals[i]);
            }
        }
    }

    function _govCompound(uint64 _validator) internal {
        if (getDelegated(_validator) == 0) return;

        bool success = MONAD_STAKIING.compound(_validator);
        if (!success) revert FailedCompound();
    }
}
