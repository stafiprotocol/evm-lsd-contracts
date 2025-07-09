// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IStakePool.sol";
import "./interfaces/IStaking.sol";
import "../base/Ownable.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, IStakePool {
    // Custom errors to provide more descriptive revert messages.
    error FailedToWithdrawForStaker();

    using SafeERC20 for IERC20;

    address public stakeManagerAddress;
    address public stakingAddress;
    uint256 public stakingPoolId;
    uint256 public stakingPoolMinStakeAmount;
    address public stakeTokenAddress;

    uint256 public pendingBond;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert CallerNotAllowed();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeManagerAddress, address _stakingAddress, address _owner, uint256 _stakingPoolId)
        external
        initializer
    {
        if (_stakeManagerAddress == address(0) || _stakingAddress == address(0) || _owner == address(0)) {
            revert AddressNotAllowed();
        }

        stakeManagerAddress = _stakeManagerAddress;
        stakingAddress = _stakingAddress;
        stakingPoolId = _stakingPoolId;
        stakeTokenAddress = address(IStaking(stakingAddress).getPoolInfo(stakingPoolId).stakeToken);
        stakingPoolMinStakeAmount = IStaking(stakingAddress).getPoolInfo(stakingPoolId).minStakeAmount;

        _transferOwnership(_owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getTotalStaked() external view override returns (uint256) {
        return IStaking(stakingAddress).getUserInfo(stakingPoolId, address(this)).amount + pendingBond;
    }

    function getStakingPoolUnbondingSeconds() external view override returns (uint256) {
        return IStaking(stakingAddress).getPoolInfo(stakingPoolId).unbondingSeconds;
    }

    // ------------ stakeManager ------------

    function stake(uint256 _amount) external override onlyStakeManager {
        uint256 willBondAmount = pendingBond + _amount;
        if (willBondAmount < stakingPoolMinStakeAmount) {
            pendingBond = willBondAmount;
            return;
        }
        pendingBond = 0;

        IStaking(stakingAddress).stake(stakingPoolId, willBondAmount);
    }

    function unstake(uint256 _amount) external override onlyStakeManager {
        if (_amount <= pendingBond) {
            pendingBond -= _amount;
            return;
        }
        uint256 willUnbondAmount = _amount - pendingBond;
        pendingBond = 0;

        IStaking(stakingAddress).unstake(stakingPoolId, willUnbondAmount);
    }

    function withdraw() external override onlyStakeManager {
        IStaking(stakingAddress).withdraw(stakingPoolId);
    }

    function claim() external override onlyStakeManager {
        IStaking(stakingAddress).claim(stakingPoolId, true);
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            IERC20(stakeTokenAddress).safeTransfer(_staker, _amount);
        }
    }

    function approveForStakeManager(uint256 amount) external override onlyStakeManager {
        IERC20(stakeTokenAddress).safeIncreaseAllowance(stakingAddress, amount);
    }
}
