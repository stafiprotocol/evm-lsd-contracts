pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "../../interfaces/IStakePool.sol";

interface IBnbStakePool is IStakePool {
    function checkAndClaimReward() external returns (uint256);

    function checkAndClaimUndelegated() external returns (uint256);

    function withdrawForStaker(address staker, uint256 amount) external;

    function getTotalDelegated() external view returns (uint256);

    function getMinDelegation() external view returns (uint256);

    function getPendingUndelegateTime(address validator) external view returns (uint256);

    function getPendingRedelegateTime(address valSrc, address valDst) external view returns (uint256);

    function getRequestInFly() external view returns (uint256[3] memory);

    function getRelayerFee() external view returns (uint256);
}
