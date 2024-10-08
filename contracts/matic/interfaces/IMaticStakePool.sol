// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IMaticStakePool {
    function delegate(uint256 validator, uint256 amount) external returns (uint256 amountToDeposit);

    function undelegate(uint256 validator, uint256 claimAmount) external;

    function redelegate(uint256 fromValidatorId, uint256 toValidatorId, uint256 amount) external;

    function checkAndWithdrawRewards(uint256[] calldata validator) external returns (uint256 reward);

    function unstakeClaimTokens(uint256 validator, uint256 claimedNonce) external returns (uint256);

    function withdrawForStaker(address erc20TokenAddress, address staker, uint256 amount) external;

    function approveForStakeManager(address erc20TokenAddress, uint256 amount) external;

    function getDelegated(uint256 validator) external view returns (uint256);

    function getTotalDelegated(uint256[] calldata validator) external view returns (uint256);
}
