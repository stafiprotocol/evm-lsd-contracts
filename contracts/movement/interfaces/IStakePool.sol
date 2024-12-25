// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IStakePool {
    function stake(uint256 amount) external returns (uint256 amountToDeposit);

    function unstake(uint256 claimAmount) external;

    function withdrawForStaker(address erc20TokenAddress, address staker, uint256 amount) external;

    function approveForStakeManager(address erc20TokenAddress, uint256 amount) external;

    function getTotalStaked() external view returns (uint256);
    
    function getReward() external view returns (uint256);
}
