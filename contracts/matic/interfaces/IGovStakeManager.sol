// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IGovStakeManager {
    function migrateDelegation(uint256 fromValidatorId, uint256 toValidatorId, uint256 amount) external;

    function epoch() external view returns (uint256);

    function withdrawalDelay() external view returns (uint256);

    function getValidatorContract(uint256 validatorId) external view returns (address);
}
