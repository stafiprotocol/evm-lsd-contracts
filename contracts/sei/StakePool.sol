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
    error FailedToWithdrawRewards();
    error FailedToWithdrawForStaker();
    error NotEnoughAmountToUndelegate();

    event Delegate(string validator, uint256 amount);
    event Undelegate(string validator, uint256 amount);
    event Redelegate(string srcValidator, string dstValidator, uint256 amount);

    using EnumerableSet for EnumerableSet.UintSet;

    uint256 constant TWELVE_DECIMALS = 1e12;
    uint256 constant MAX_ENTRIES = 7;
    uint256 constant UNBONDING_SECONDS = 1814400;
    address constant STAKING_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000001005;
    address constant DISTR_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000001007;

    address public stakeManagerAddress;

    mapping(string => uint256) delegatedAmountOfValidator; //  validator => amount(decimals 6)
    mapping(string => EnumerableSet.UintSet) undelegateTimestampsOfValidator; //  validator => undelegateTimestamp[]

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

    function delegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 willDelegateAmount = _amount / TWELVE_DECIMALS;
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
            if (!IGovStaking(STAKING_PRECOMPILE_ADDRESS).delegate(_validators[i], amount)) {
                revert FailedToDelegate();
            }

            delegatedAmountOfValidator[_validators[i]] += amount;

            emit Delegate(_validators[i], amount * TWELVE_DECIMALS);
        }
    }

    function undelegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 needUndelegate = _amount / TWELVE_DECIMALS;
        if (needUndelegate == 0) {
            revert UndelegateAmountTooSmall();
        }

        for (uint256 i = 0; i < _validators.length; ++i) {
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

            if (undelegateTimestampsOfValidator[val].length() >= MAX_ENTRIES) {
                continue;
            }

            uint256 govDelegated = delegatedAmountOfValidator[val];

            uint256 willUndelegate = needUndelegate < govDelegated ? needUndelegate : govDelegated;

            if (!IGovStaking(STAKING_PRECOMPILE_ADDRESS).undelegate(val, willUndelegate)) {
                revert FailedToUndelegate();
            }
            needUndelegate -= willUndelegate;

            delegatedAmountOfValidator[val] -= willUndelegate;
            undelegateTimestampsOfValidator[val].add(block.timestamp);

            emit Undelegate(val, willUndelegate * TWELVE_DECIMALS);
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
        IGovStaking(STAKING_PRECOMPILE_ADDRESS).redelegate(_validatorSrc, _validatorDst, willRedelegateAmount);

        delegatedAmountOfValidator[_validatorSrc] -= willRedelegateAmount;
        delegatedAmountOfValidator[_validatorDst] += willRedelegateAmount;

        emit Redelegate(_validatorSrc, _validatorDst, willRedelegateAmount * TWELVE_DECIMALS);
    }

    function withdrawDelegationRewardsMulti(
        string[] memory _validators
    ) external override onlyStakeManager returns (uint256) {
        uint256 preBalance = address(this).balance;
        for (uint256 i = 0; i < _validators.length; ++i) {
            if (delegatedAmountOfValidator[_validators[i]] == 0) {
                continue;
            }

            if (!IGovDistribution(DISTR_PRECOMPILE_ADDRESS).withdrawDelegationRewards(_validators[i])) {
                revert FailedToWithdrawRewards();
            }
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
        return delegatedAmountOfValidator[_validator] * TWELVE_DECIMALS;
    }

    function getTotalDelegated(string[] calldata _validators) external view override returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < _validators.length; ++i) {
            total += delegatedAmountOfValidator[_validators[i]] * TWELVE_DECIMALS;
        }
        return total;
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
