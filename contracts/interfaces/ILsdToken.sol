// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface ILsdToken {
    function mint(address to, uint256 amount) external;

    function initStakeManager(address _stakeManagerAddress) external;
}
