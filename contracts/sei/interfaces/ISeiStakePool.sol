pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface ISeiStakePool {
    function delegate(string memory validator, uint256 amount) external;

    function undelegate(string memory validator, uint256 amount) external;

    function redelegate(string memory validatorSrc, string memory validatorDst, uint256 amount) external;

    function getDelegated(string memory validator) external view returns (uint256);

    function withdrawForStaker(address staker, uint256 amount) external;
}
