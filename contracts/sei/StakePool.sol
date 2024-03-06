// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../base/Ownable.sol";
import "./interfaces/IGovStaking.sol";
import "./interfaces/IGovDistribution.sol";
import "./interfaces/ISeiStakePool.sol";
import "../LsdToken.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, ISeiStakePool {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error NotValidAddress();
    error FailedToWithdrawForStaker();
    error NotEnoughAmountToUndelegate();

    event Delegate(string validator, uint256 amount);
    event Undelegate(string validator, uint256 amount);

    uint256 public constant TEN_DECIMALS = 1e10;

    address public stakingAddress;
    address public distributionAddress;
    address public stakeManagerAddress;

    uint256 unbondingTimesLimit;
    uint256 unbondingDuration;

    mapping(string => uint256) delegatedAmountOfValidator; //  validator => amount
    mapping(string => uint256[]) undelegateTimestamps; //  validator => undelegateTimestamp[]
    mapping(string => mapping(string => uint256)) redelegateTimestamps; // srcValidator => dstValidator => undelegateTimestamp[]

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stakingAddress,
        address _distributionAddress,
        address _stakeManagerAddress,
        address _owner
    ) external virtual initializer {
        if (_stakeManagerAddress == address(0)) revert NotValidAddress();

        _transferOwnership(_owner);
        stakingAddress = _stakingAddress;
        distributionAddress = _distributionAddress;
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    function delegate(string memory _validator, uint256 _amount) external override onlyStakeManager {
        IGovStaking(stakingAddress).delegate(_validator, _amount);
    }

    function undelegate(string memory _validator, uint256 _amount) external override onlyStakeManager {
        IGovStaking(stakingAddress).undelegate(_validator, _amount);
    }

    function delegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 averageAmount = _amount / _validators.length;
        for (uint256 i = 0; i < _validators.length; ++i) {
            if (i == _validators.length - 1) {
                IGovStaking(stakingAddress).delegate(
                    _validators[i],
                    _amount - (averageAmount * (_validators.length - 1))
                );
            } else {
                IGovStaking(stakingAddress).delegate(_validators[i], averageAmount);
            }
        }
    }

    function undelegateMulti(string[] memory _validators, uint256 _amount) external override onlyStakeManager {
        uint256 needUndelegate = _amount;
        for (uint256 i = 0; i < _validators.length; ++i) {
            if (needUndelegate == 0) {
                break;
            }
            string memory val = _validators[i];

            uint256 govDelegated = delegatedAmountOfValidator[val];
            if (needUndelegate < govDelegated) {
                uint256 willUndelegate = needUndelegate;

                delegatedAmountOfValidator[val] = delegatedAmountOfValidator[val] - willUndelegate;
                IGovStaking(stakingAddress).undelegate(val, willUndelegate);

                emit Undelegate(val, willUndelegate);

                needUndelegate = 0;
            } else {
                delegatedAmountOfValidator[val] = delegatedAmountOfValidator[val] - govDelegated;
                IGovStaking(stakingAddress).undelegate(val, govDelegated);

                emit Undelegate(val, govDelegated);

                needUndelegate = needUndelegate - govDelegated;
            }
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
        IGovStaking(stakingAddress).redelegate(_validatorSrc, _validatorDst, _amount);
    }

    function setWithdrawAddress(address _withdrawAddress) external override onlyStakeManager {
        IGovDistribution(distributionAddress).setWithdrawAddress(_withdrawAddress);
    }

    function withdrawDelegationRewards(
        string memory _validator
    ) external override onlyStakeManager returns (bool success) {
        return IGovDistribution(distributionAddress).withdrawDelegationRewards(_validator);
    }

    function withdrawDelegationRewardsMulti(
        string[] memory _validators
    ) external override onlyStakeManager returns (bool success) {
        for (uint256 i = 0; i < _validators.length; ++i) {
            if (!IGovDistribution(distributionAddress).withdrawDelegationRewards(_validators[i])) {
                return false;
            }
        }
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
