pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface IRateProvider {
    function getRate() external view returns (uint256);
}
