// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IGovDistribution {
    function setWithdrawAddress(address withdrawAddr) external returns (bool success);

    function withdrawDelegationRewards(string memory validator) external returns (bool success);
}
