// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IStakeCredit {
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);

    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);

    function balanceOf(address delegator) external view returns (uint256);

    function getPooledBNB(address account) external view returns (uint256);

    function claimableUnbondRequest(address delegator) external view returns (uint256);
}
