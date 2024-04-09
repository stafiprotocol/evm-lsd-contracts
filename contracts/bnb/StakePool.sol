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
    error DelegateAmountTooSmall();
    error UndelegateAmountTooSmall();
    error FailedToDelegate();
    error FailedToUndelegate();
    error FailedToRedelegate();
    error FailedToWithdrawRewards();
    error FailedToWithdrawForStaker();
    error NotEnoughAmountToUndelegate();
    error ValidatorsEmpty();

    event Delegate(address validator, uint256 amount);
    event Undelegate(address validator, uint256 amount);
    event Redelegate(address srcValidator, address dstValidator, uint256 amount);

    using EnumerableSet for EnumerableSet.UintSet;

    address public constant stakeHubAddress = 0x0000000000000000000000000000000000002002;

    address public stakeManagerAddress;
    uint256 public lastUndelegateIndex;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeManagerAddress, address _owner) external virtual initializer {
        if (_stakeManagerAddress == address(0)) revert NotValidAddress();

        _transferOwnership(_owner);
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    function _govDelegate(address _validator, uint256 _amount) internal virtual {
        IStakeHub(stakeHubAddress).delegate{value: _amount}(_validator, false);
    }

    function _govUndelegate(address _validator, uint256 _amount) internal virtual {
        IStakeHub stakeHub = IStakeHub(stakeHubAddress);
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validator));
        uint256 share = stakeCredit.getSharesByPooledBNB(_amount);

        stakeHub.undelegate(_validator, share);
    }

    function _govRedelegate(address _srcValidator, address _dstValidator, uint256 _amount) internal virtual {
        IStakeHub stakeHub = IStakeHub(stakeHubAddress);
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_srcValidator));
        uint256 share = stakeCredit.getSharesByPooledBNB(_amount);

        stakeHub.redelegate(_srcValidator, _dstValidator, share, false);
    }

    function delegateMulti(address[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 willDelegateAmount = _amount;
        if (willDelegateAmount == 0) {
            revert DelegateAmountTooSmall();
        }

        uint256 averageAmount = willDelegateAmount / _validators.length;
        uint256 tail = willDelegateAmount % _validators.length;

        for (uint256 i = 0; i < _validators.length; ++i) {
            uint256 amount = averageAmount;
            if (i == 0) {
                amount = averageAmount + tail;
            }
            if (amount == 0) {
                break;
            }
            _govDelegate(_validators[i], amount);

            emit Delegate(_validators[i], amount);
        }
    }

    function undelegateMulti(address[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 needUndelegate = _amount;
        if (needUndelegate == 0) {
            revert UndelegateAmountTooSmall();
        }
        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

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

            emit Undelegate(val, willUndelegate);

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
    ) external override onlyStakeManager {
        _govRedelegate(_validatorSrc, _validatorDst, _amount);

        emit Redelegate(_validatorSrc, _validatorDst, _amount);
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            (bool result, ) = _staker.call{value: _amount}("");
            if (!result) revert FailedToWithdrawForStaker();
        }
    }

    function getDelegated(address _validator) public view override returns (uint256) {
        IStakeHub stakeHub = IStakeHub(stakeHubAddress);
        IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validator));
        return stakeCredit.getPooledBNB(address(this));
    }

    function getTotalDelegated(address[] calldata _validators) external view override returns (uint256) {
        uint256 totalBnbAmount;
        IStakeHub stakeHub = IStakeHub(stakeHubAddress);
        for (uint256 i = 0; i < _validators.length; ++i) {
            IStakeCredit stakeCredit = IStakeCredit(stakeHub.getValidatorCreditContract(_validators[i]));
            totalBnbAmount += stakeCredit.getPooledBNB(address(this));
        }
        return totalBnbAmount;
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
