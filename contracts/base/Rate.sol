pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Ownable.sol";
import "../interfaces/IRateProvider.sol";

abstract contract Rate is Ownable, IRateProvider {
    // Custom errors to provide more descriptive revert messages.
    error LessThanMinRateChangeLimit(uint256 rateChangeLimit);
    error GreaterThanMaxRateChangeLimit(uint256 rateChangeLimit);
    error RateChangeExceedLimit(uint256 oldRate, uint256 newRate);
    
    uint256 public constant MIN_RATE_CHANGE_LIMIT = 1e13;
    uint256 public constant MAX_RATE_CHANGE_LIMIT = 5 * 1e15;

    uint256 public rate;
    uint256 public rateChangeLimit;
    mapping(uint256 => uint256) public eraRate;

    function getRate() public view virtual override returns (uint256) {
        return rate;
    }

    function setRateChangeLimit(uint256 _rateChangeLimit) external virtual onlyOwner {
        _setRateChangeLimit(_rateChangeLimit);
    }

    function _initRateParams(uint256 _rateChangeLimit) internal virtual {
        if (rate != 0) revert AlreadyInitialized();

        _setRateChangeLimit(_rateChangeLimit);
        rate = 1e18;
        eraRate[0] = rate;
    }
    
    function _setRateChangeLimit(uint256 _rateChangeLimit) internal virtual {
        if (_rateChangeLimit < MIN_RATE_CHANGE_LIMIT) revert LessThanMinRateChangeLimit(_rateChangeLimit);
        if (_rateChangeLimit > MAX_RATE_CHANGE_LIMIT) revert GreaterThanMaxRateChangeLimit(_rateChangeLimit);

        rateChangeLimit = _rateChangeLimit;
    }

    function _setEraRate(uint256 _era, uint256 _rate) internal virtual {
        uint256 rateChange = _rate > rate ? _rate - rate : rate - _rate;
        if ((rateChange * 1e18) / rate > rateChangeLimit) revert RateChangeExceedLimit(rate, _rate);

        rate = _rate;
        eraRate[_era] = rate;
    }
}
