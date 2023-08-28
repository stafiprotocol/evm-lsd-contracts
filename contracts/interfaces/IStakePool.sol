pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface IStakePool {
    function delegate(address validator, uint256 amount) external;

    function undelegate(address validator, uint256 amount) external;

    function redelegate(address validatorSrc, address validatorDst, uint256 amount) external;

    function getDelegated(address validator) external view returns (uint256);
}
