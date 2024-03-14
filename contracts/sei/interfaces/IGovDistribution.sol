// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IGovDistribution {
    function withdrawDelegationRewards(string memory validator) external returns (bool success);
}
