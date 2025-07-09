// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IStaking {
    struct UserInfo {
        uint256 amount;
        uint256 reward;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        address admin;
        IERC20 stakeToken;
        uint256 minStakeAmount;
        uint256 rewardRate;
        uint256 totalStake;
        RewardAlgorithm rewardAlgorithm;
        uint256 totalReward;
        uint256 undistributedReward;
        uint256 lastRewardTimestamp;
        uint256 rewardPerShare;
        uint256 unbondingSeconds;
        uint256 nextUnstakeIndex;
    }

    enum RewardAlgorithm {
        FixedPerTokenPerSecond,
        FixedTotalPerSecond
    }

    function getUserInfo(uint256 _pid, address _staker) external view returns (UserInfo memory);

    function getPoolInfo(uint256 _pid) external view returns (PoolInfo memory);

    function stake(uint256 _pid, uint256 _amount) external;
    function unstake(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid) external;
    function claim(uint256 _pid, bool restake) external;
}
