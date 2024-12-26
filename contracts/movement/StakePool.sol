// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IStakePool.sol";
import "./interfaces/IMovementStaking.sol";
import "./interfaces/IMCR.sol";
import "../base/Ownable.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, IStakePool, IMCR {
    // Custom errors to provide more descriptive revert messages.
    error FailedToWithdrawForStaker();

    using SafeERC20 for IERC20;

    address public stakeManagerAddress;
    address public movementStakingAddress;
    address public movementMCRAddress;
    address public attester;
    address public stakeTokenAddress;

    uint256 public totalUnstakeButNotWithdrawAmount;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert CallerNotAllowed();
        _;
    }

    modifier onlyAttester() {
        if (attester != msg.sender) revert CallerNotAllowed();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stakeManagerAddress,
        address _movementStakingAddress,
        address _movementMCRAddress,
        address _owner,
        address _attester,
        address _stakeTokenAddress
    ) external initializer {
        if (
            _stakeManagerAddress == address(0) ||
            _movementStakingAddress == address(0) ||
            _movementMCRAddress == address(0) ||
            _owner == address(0) ||
            _attester == address(0) ||
            _stakeTokenAddress == address(0)
        ) {
            revert AddressNotAllowed();
        }

        stakeManagerAddress = _stakeManagerAddress;
        movementStakingAddress = _movementStakingAddress;
        movementMCRAddress = _movementMCRAddress;
        attester = _attester;
        stakeTokenAddress = _stakeTokenAddress;

        _transferOwnership(_owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getTotalStaked() external view override returns (uint256) {
        IMovementStaking movementStaking = IMovementStaking(movementStakingAddress);
        uint256 maxEpoch = movementStaking.getNextEpochByBlockTime(movementMCRAddress);
        uint256 minEpoch = movementStaking.getCurrentEpoch(movementMCRAddress);
        uint256 totalStakeAmount;
        for (uint256 i = minEpoch; i <= maxEpoch; i++) {
            totalStakeAmount += movementStaking.getStakeAtEpoch(
                movementMCRAddress,
                i,
                stakeTokenAddress,
                address(this)
            );
        }
        return totalStakeAmount;
    }

    // poolBalance = bond + payedUnstakeButNotWithdraw + payedReward
    // totalUnstakeButNotWithdraw = pendingUnstake + payedUnstakeButNotWithdraw
    function getReward(uint256 _bond) external view override returns (uint256) {
        IMovementStaking movementStaking = IMovementStaking(movementStakingAddress);
        uint256 poolBalance = IERC20(stakeTokenAddress).balanceOf(address(this));
        uint256 maxEpoch = movementStaking.getNextEpochByBlockTime(movementMCRAddress);
        uint256 minEpoch = movementStaking.getCurrentEpoch(movementMCRAddress);
        uint256 pendingUnstake;
        for (uint256 i = minEpoch + 1; i <= maxEpoch; i++) {
            pendingUnstake += movementStaking.getUnstakeAtEpoch(
                movementMCRAddress,
                i,
                stakeTokenAddress,
                address(this)
            );
        }

        return poolBalance - _bond - (totalUnstakeButNotWithdrawAmount - pendingUnstake);
    }

    // ------------ stakeManager ------------

    function stake(uint256 _amount) external override onlyStakeManager {
        IMovementStaking(movementStakingAddress).stake(movementMCRAddress, IERC20(stakeTokenAddress), _amount);
    }

    function unstake(uint256 _amount) external override onlyStakeManager {
        totalUnstakeButNotWithdrawAmount += _amount;
        IMovementStaking(movementStakingAddress).unstake(movementMCRAddress, stakeTokenAddress, _amount);
    }

    function withdrawForStaker(address _staker, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            totalUnstakeButNotWithdrawAmount -= _amount;
            IERC20(stakeTokenAddress).safeTransfer(_staker, _amount);
        }
    }

    function approveForStakeManager(uint256 amount) external override onlyStakeManager {
        IERC20(stakeTokenAddress).safeIncreaseAllowance(movementStakingAddress, amount);
    }

    function submitBlockCommitment(BlockCommitment memory blockCommitment) external override onlyAttester {
        IMCR(movementMCRAddress).submitBlockCommitment(blockCommitment);
    }

    function submitBatchBlockCommitment(BlockCommitment[] memory blockCommitments) external override onlyAttester {
        IMCR(movementMCRAddress).submitBatchBlockCommitment(blockCommitments);
    }
}
