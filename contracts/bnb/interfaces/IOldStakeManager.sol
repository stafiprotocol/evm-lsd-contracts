// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "../../base/Errors.sol";

interface IOldStakeManager is Errors {
    function getRate() external returns (uint256);

    function eraOffset() external returns (uint256);

    function latestEra() external returns (uint256);

    function totalRTokenSupply() external returns (uint256);

    function totalProtocolFee() external returns (uint256);

    function poolInfoOf(address pool) external returns (OldPoolInfo memory poolInfo);
}

struct OldPoolInfo {
    uint256 era;
    uint256 bond;
    uint256 unbond;
    uint256 active;
}
