pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Era.sol";
import "./Rate.sol";
import "./StakePool.sol";
import "./UnstakePool.sol";
import "./Protocol.sol";
import "./DelegationBalancer.sol";

abstract contract Manager is Era, Rate, StakePool, UnstakePool, Protocol, DelegationBalancer {
    function _initManagerParams(
        address _lsdToken,
        address _poolAddress,
        uint256 _unbondingDuration,
        uint256 _rateChangeLimit
    ) internal virtual {
        _initProtocolParams(_lsdToken);
        _initEraParams();
        _initRateParams(_rateChangeLimit);
        _initStakePoolParams(_poolAddress);
        _initUnstakeParams(_unbondingDuration);
        _initDelegationBalancer();
    }
}
