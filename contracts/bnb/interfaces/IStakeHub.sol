pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface IStakeHub {
    function delegate(address operatorAddress, bool delegateVotePower) external payable;

    function undelegate(address operatorAddress, uint256 shares) external;

    function redelegate(address srcValidator, address dstValidator, uint256 shares, bool delegateVotePower) external;

    function claim(address operatorAddress, uint256 requestNumber) external;

    function getValidatorCreditContract(address operatorAddress) external view returns (address creditContract);

    function minDelegationBNBChange() external view returns (uint256);

    function redelegateFeeRate() external view returns (uint256);

    function REDELEGATE_FEE_RATE_BASE() external view returns (uint256);
}
