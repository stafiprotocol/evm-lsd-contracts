// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

interface IMonadStaking {
    function delegate(uint64 validatorId) external payable returns (bool success);

    function undelegate(uint64 validatorId, uint256 amount, uint8 withdrawId) external returns (bool success);

    function compound(uint64 validatorId) external returns (bool success);

    function withdraw(uint64 validatorId, uint8 withdrawId) external returns (bool success);

    function getDelegator(uint64 validatorId, address delegator)
        external
        view
        returns (
            uint256 stake,
            uint256 accRewardPerToken,
            uint256 unclaimedRewards,
            uint256 deltaStake,
            uint256 nextDeltaStake,
            uint64 deltaEpoch,
            uint64 nextDeltaEpoch
        );

    function getWithdrawalRequest(uint64 validatorId, address delegator, uint8 withdrawId)
        external
        returns (uint256 withdrawalAmount, uint256 accRewardPerToken, uint64 withdrawEpoch);

    function getEpoch() external returns (uint64 epoch, bool inEpochDelayPeriod);
}
