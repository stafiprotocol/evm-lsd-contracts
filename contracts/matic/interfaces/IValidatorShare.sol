// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IValidatorShare {
    struct DelegatorUnbond {
        uint256 shares;
        uint256 withdrawEpoch;
    }

    function withdrawRewards() external;

    function buyVoucherPOL(uint256 _amount, uint256 _minSharesToMint) external returns (uint256 amountToDeposit);

    function sellVoucher_newPOL(uint256 claimAmount, uint256 maximumSharesToBurn) external;

    function unstakeClaimTokens_newPOL(uint256 unbondNonce) external;

    function restake() external returns (uint256, uint256);

    function getTotalStake(address user) external view returns (uint256, uint256);

    function getLiquidRewards(address user) external view returns (uint256);

    function unbonds_new(address user, uint256 nonce) external view returns (DelegatorUnbond calldata);
}
