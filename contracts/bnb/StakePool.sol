// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../base/Ownable.sol";
import "./interfaces/IBnbStakePool.sol";
import "../LsdToken.sol";
import "./interfaces/IStakeHub.sol";
import "./interfaces/IStakeCredit.sol";
import "./interfaces/IBnbStakePool.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, IBnbStakePool {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error NotValidAddress();
    error AmountZero();
    error FailedToWithdrawForStaker();
    error NotEnoughAmountToUndelegate();
    error NotEnoughRedelegateFee();
    error ValidatorsEmpty();

    event Delegate(address validator, uint256 amount);
    event Undelegate(address validator, uint256 amount);
    event Redelegate(address srcValidator, address dstValidator, uint256 amount);
    event WithdrawForStaker(address staker, uint256 amount);
    event ClaimUndelegated(address validator, uint256 number);

    IStakeHub constant stakeHub = IStakeHub(0x0000000000000000000000000000000000002002);

    address public stakeManagerAddress;
    uint256 public lastUndelegateIndex;
    uint256 public pendingDelegate;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeManagerAddress, address _owner) external initializer {
        if (_stakeManagerAddress == address(0) || _owner == address(0)) revert NotValidAddress();

        _transferOwnership(_owner);
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getDelegated(address _validator) public view override returns (uint256) {
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validator));
        return stakeCredit.getPooledBNB(address(this));
    }

    function getTotalDelegated(address[] calldata _validators) external view override returns (uint256) {
        uint256 totalBnbAmount = pendingDelegate;
        for (uint256 i = 0; i < _validators.length; ++i) {
            IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validators[i]));
            totalBnbAmount += stakeCredit.getPooledBNB(address(this));
        }
        return totalBnbAmount;
    }

    // ------------ stakeManager ------------

    function delegateMulti(address[] memory _validators, uint256 _amount) external override onlyStakeManager {
        if (_amount == 0) {
            revert AmountZero();
        }
        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }
        uint256 willDelegateAmount = pendingDelegate + _amount;

        uint256 minDelegationAmount = stakeHub.minDelegationBNBChange();
        if (willDelegateAmount < minDelegationAmount) {
            pendingDelegate = willDelegateAmount;
            return;
        }

        uint256 averageAmount = willDelegateAmount / _validators.length;
        if (averageAmount < minDelegationAmount) {
            pendingDelegate = 0;

            _govDelegate(_validators[0], willDelegateAmount);

            return;
        }

        uint256 tail = willDelegateAmount % _validators.length;
        for (uint256 i = 0; i < _validators.length; ++i) {
            uint256 amount = i == 0 ? averageAmount + tail : averageAmount;

            _govDelegate(_validators[i], amount);
        }

        pendingDelegate = 0;
    }

    function undelegateMulti(address[] memory _validators, uint256 _amount) external override onlyStakeManager {
        if (_amount == 0) {
            revert AmountZero();
        }
        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

        if (pendingDelegate >= _amount) {
            pendingDelegate -= _amount;
            return;
        }

        uint256 needUndelegate = _amount - pendingDelegate;

        pendingDelegate = 0;

        uint256 totalCycle = 0;
        for (
            uint256 i = (lastUndelegateIndex + 1) % _validators.length;
            totalCycle < _validators.length;
            (i = (i + 1) % _validators.length, ++totalCycle)
        ) {
            if (needUndelegate == 0) {
                break;
            }

            address val = _validators[i];

            uint256 govDelegated = getDelegated(val);

            uint256 willUndelegate = needUndelegate < govDelegated ? needUndelegate : govDelegated;

            _govUndelegate(val, willUndelegate);
            needUndelegate -= willUndelegate;

            lastUndelegateIndex = i;
        }

        if (needUndelegate > 0) {
            revert NotEnoughAmountToUndelegate();
        }
    }

    function redelegate(
        address _validatorSrc,
        address _validatorDst,
        uint256 _amount
    ) external payable override onlyStakeManager {
        uint256 redelegateFee = (_amount * stakeHub.redelegateFeeRate()) / stakeHub.REDELEGATE_FEE_RATE_BASE();
        if (msg.value < redelegateFee) revert NotEnoughRedelegateFee();
        _govRedelegate(_validatorSrc, _validatorDst, _amount, msg.value);
    }

    function claimUndelegated(address[] memory _validators) external override onlyStakeManager {
        for (uint256 i = 0; i < _validators.length; ++i) {
            _govClaimUndelegated(_validators[i]);
        }
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_staker == address(0)) revert NotValidAddress();
        if (_amount > 0) {
            (bool result, ) = _staker.call{value: _amount}("");
            if (!result) revert FailedToWithdrawForStaker();

            emit WithdrawForStaker(_staker, _amount);
        }
    }

    function _govDelegate(address _validator, uint256 _amount) internal {
        stakeHub.delegate{value: _amount}(_validator, false);

        emit Delegate(_validator, _amount);
    }

    function _govUndelegate(address _validator, uint256 _amount) internal {
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validator));
        uint256 share = stakeCredit.getSharesByPooledBNB(_amount);
        uint256 balance = stakeCredit.balanceOf(address(this));
        if (stakeCredit.getPooledBNBByShares(share) < _amount && share < balance) {
            share += 1;
        }
        if (share > balance) {
            share = balance;
        }

        stakeHub.undelegate(_validator, share);

        emit Undelegate(_validator, _amount);
    }

    function _govClaimUndelegated(address _validator) internal {
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validator));
        uint256 number = stakeCredit.claimableUnbondRequest(address(this));
        if (number > 0) {
            stakeHub.claim(_validator, number);
            emit ClaimUndelegated(_validator, number);
        }
    }

    function _govRedelegate(address _srcValidator, address _dstValidator, uint256 _amount, uint256 _fee) internal {
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_srcValidator));
        uint256 share = stakeCredit.getSharesByPooledBNB(_amount);

        stakeHub.redelegate(_srcValidator, _dstValidator, share, false);

        if (_fee > 0) {
            uint256 minDelegationAmount = stakeHub.minDelegationBNBChange();
            uint256 willDelegateAmount = pendingDelegate + _fee;
            if (willDelegateAmount < minDelegationAmount) {
                pendingDelegate = willDelegateAmount;
            } else {
                _govDelegate(_dstValidator, willDelegateAmount);
                pendingDelegate = 0;
            }
        }

        emit Redelegate(_srcValidator, _dstValidator, _amount);
    }
}
