// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../base/Ownable.sol";
import "./interfaces/IGovStaking.sol";
import "./interfaces/IGovDistribution.sol";
import "./interfaces/ISeiStakePool.sol";
import "../LsdToken.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, ISeiStakePool {
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

    event Delegate(string validator, uint256 amount);
    event Undelegate(string validator, uint256 amount);
    event Redelegate(string srcValidator, string dstValidator, uint256 amount);

    using EnumerableSet for EnumerableSet.UintSet;

    uint256 constant TWELVE_DECIMALS = 1e12;
    uint256 constant MAX_UNDELEGATING_ENTRIES = 7;
    uint256 constant UNBONDING_SECONDS = 1814400; // 21 days
    address constant STAKING_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000001005;
    address constant DISTR_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000001007;

    address public stakeManagerAddress;

    mapping(string => uint256) delegatedAmountOfValidator; //  validator => amount(decimals 18)
    mapping(string => EnumerableSet.UintSet) undelegateTimestampsOfValidator; //  validator => undelegateTimestamp[]

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

    function _govDelegate(string memory validator, uint256 amount) internal virtual {
        if (!IGovStaking(STAKING_PRECOMPILE_ADDRESS).delegate{value: amount}(validator)) {
            revert FailedToDelegate();
        }
    }

    function _govUndelegate(string memory validator, uint256 amount) internal virtual {
        if (!IGovStaking(STAKING_PRECOMPILE_ADDRESS).undelegate(validator, amount)) {
            revert FailedToUndelegate();
        }
    }

    function _govRedelegate(string memory srcValidator, string memory dstValidator, uint256 amount) internal virtual {
        if (!IGovStaking(STAKING_PRECOMPILE_ADDRESS).redelegate(srcValidator, dstValidator, amount)) {
            revert FailedToRedelegate();
        }
    }

    function _govWithdrawRewards(string memory validator) internal virtual {
        if (!IGovDistribution(DISTR_PRECOMPILE_ADDRESS).withdrawDelegationRewards(validator)) {
            revert FailedToWithdrawRewards();
        }
    }

    function delegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 willDelegateAmount = _amount / TWELVE_DECIMALS;
        if (willDelegateAmount == 0) {
            revert DelegateAmountTooSmall();
        }

        uint256 averageAmount = (willDelegateAmount / _validators.length) * TWELVE_DECIMALS;
        uint256 tail = (willDelegateAmount % _validators.length) * TWELVE_DECIMALS;

        for (uint256 i = 0; i < _validators.length; ++i) {
            uint256 amount = averageAmount;
            if (i == 0) {
                amount = averageAmount + tail;
            }
            if (amount == 0) {
                break;
            }
            _govDelegate(_validators[i], amount);

            delegatedAmountOfValidator[_validators[i]] += amount;

            emit Delegate(_validators[i], amount);
        }
    }

    function undelegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 needUndelegate = _amount / TWELVE_DECIMALS;
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

            string memory val = _validators[i];

            for (uint256 j = 0; j < undelegateTimestampsOfValidator[val].length(); ++j) {
                uint256 value = undelegateTimestampsOfValidator[val].at(j);
                if ((value + UNBONDING_SECONDS) < block.timestamp) {
                    undelegateTimestampsOfValidator[val].remove(value);
                }
            }

            if (undelegateTimestampsOfValidator[val].length() >= MAX_UNDELEGATING_ENTRIES) {
                continue;
            }

            uint256 govDelegated = delegatedAmountOfValidator[val] / TWELVE_DECIMALS;

            uint256 willUndelegate = needUndelegate < govDelegated ? needUndelegate : govDelegated;

            _govUndelegate(val, willUndelegate);
            needUndelegate -= willUndelegate;

            delegatedAmountOfValidator[val] -= willUndelegate * TWELVE_DECIMALS;
            undelegateTimestampsOfValidator[val].add(block.timestamp);

            emit Undelegate(val, willUndelegate * TWELVE_DECIMALS);

            lastUndelegateIndex = i;
        }

        if (needUndelegate > 0) {
            revert NotEnoughAmountToUndelegate();
        }
    }

    function redelegate(
        string memory _validatorSrc,
        string memory _validatorDst,
        uint256 _amount
    ) external override onlyStakeManager {
        uint256 willRedelegateAmount = _amount / TWELVE_DECIMALS;

        _govRedelegate(_validatorSrc, _validatorDst, willRedelegateAmount);

        uint256 changedAmount = willRedelegateAmount * TWELVE_DECIMALS;

        delegatedAmountOfValidator[_validatorSrc] -= changedAmount;
        delegatedAmountOfValidator[_validatorDst] += changedAmount;

        emit Redelegate(_validatorSrc, _validatorDst, changedAmount);
    }

    function withdrawDelegationRewardsMulti(
        string[] memory _validators
    ) external override onlyStakeManager returns (uint256) {
        uint256 preBalance = address(this).balance;
        for (uint256 i = 0; i < _validators.length; ++i) {
            if (delegatedAmountOfValidator[_validators[i]] == 0) {
                continue;
            }

            _govWithdrawRewards(_validators[i]);
        }
        uint256 postBalance = address(this).balance;

        uint256 rewardAmount = postBalance > preBalance ? postBalance - preBalance : 0;

        return (rewardAmount / TWELVE_DECIMALS) * TWELVE_DECIMALS;
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            (bool result, ) = _staker.call{value: _amount}("");
            if (!result) revert FailedToWithdrawForStaker();
        }
    }

    function getDelegated(string memory _validator) external view override returns (uint256) {
        return delegatedAmountOfValidator[_validator];
    }

    function getTotalDelegated(string[] calldata _validators) external view override returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < _validators.length; ++i) {
            total += delegatedAmountOfValidator[_validators[i]];
        }
        return total;
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
