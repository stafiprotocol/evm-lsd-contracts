// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface ISeiStakePool {
    function redelegate(string memory validatorSrc, string memory validatorDst, uint256 amount) external;

    function withdrawForStaker(address staker, uint256 amount) external;

    function delegateMulti(string[] memory _validators, uint256 _amount) external;

    function undelegateMulti(string[] memory _validators, uint256 _amount) external;

    function withdrawDelegationRewardsMulti(string[] memory _validators) external returns (uint256);

    function getDelegated(string memory validator) external view returns (uint256);

    function getTotalDelegated(string[] calldata validator) external view returns (uint256);
}
