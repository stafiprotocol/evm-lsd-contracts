pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

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

    uint256 public constant TEN_DECIMALS = 1e10;

    address public stakingAddress;
    address public distributionAddress;
    address public stakeManagerAddress;

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
        if (stakingAddress != address(0)) revert AlreadyInitialized();
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

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            (bool result, ) = _staker.call{value: _amount}("");
            if (!result) revert FailedToWithdrawForStaker();
        }
    }

    function getDelegated(string memory _validator) external view override returns (uint256) {
        return IGovStaking(stakingAddress).getDelegation(address(this), _validator);
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
