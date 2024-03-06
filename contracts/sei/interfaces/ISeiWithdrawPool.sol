pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface ISeiWithdrawPool {
    function withdrawReward(address to, uint256 amount) external;
}
