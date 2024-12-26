// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IStakePool {
    function stake(uint256 amount) external;

    function unstake(uint256 claimAmount) external;

    function withdrawForStaker(address staker, uint256 amount) external;

    function approveForStakeManager(uint256 amount) external;

    function getTotalStaked() external view returns (uint256);

    function getReward(uint256 bond) external view returns (uint256);
}
