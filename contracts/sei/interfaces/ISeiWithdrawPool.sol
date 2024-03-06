// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface ISeiWithdrawPool {
    function withdrawReward(address to, uint256 amount) external;
}
