pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface ISeiStakePool {
    function delegate(string memory validator, uint256 amount) external;

    function undelegate(string memory validator, uint256 amount) external;

    function redelegate(string memory validatorSrc, string memory validatorDst, uint256 amount) external;

    function withdrawForStaker(address staker, uint256 amount) external;

    function setWithdrawAddress(address withdrawAddress) external;

    function withdrawDelegationRewards(string memory _validator) external returns (bool success);

    function delegateMulti(string[] memory _validators, uint256 _amount) external;

    function undelegateMulti(string[] memory _validators, uint256 _amount) external;

    function withdrawDelegationRewardsMulti(string[] memory _validators) external returns (bool success);

    function getDelegated(string memory validator) external view returns (uint256);

    function getTotalDelegated(string[] calldata validator) external view returns (uint256);
}
