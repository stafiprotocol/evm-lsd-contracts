pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Ownable.sol";
import "../interfaces/IRateProvider.sol";

abstract contract Rate is Ownable, IRateProvider {
    uint256 public constant MAX_RATE_CHANGE_LIMIT = 1e15;

    uint256 public rate;
    uint256 public rateChangeLimit;
    mapping(uint256 => uint256) public eraRate;

    function getRate() public view virtual override returns (uint256) {
        return rate;
    }

    function setRateChangeLimit(uint256 _rateChangeLimit) public virtual onlyOwner {
        _setRateChangeLimit(_rateChangeLimit);
    }

    function _initRateParams(uint256 _rateChangeLimit) internal virtual {
        require(rate == 0, "Rate: already init");

        _setRateChangeLimit(_rateChangeLimit);
        rate = 1e18;
        eraRate[0] = rate;
    }
    
    function _setRateChangeLimit(uint256 _rateChangeLimit) internal virtual {
        require(_rateChangeLimit > 0, "Rate: zero rate change limit");
        require(_rateChangeLimit <= MAX_RATE_CHANGE_LIMIT, "Rate: max rate change limit");

        rateChangeLimit = _rateChangeLimit;
    }

    function _setEraRate(uint256 _era, uint256 _rate) internal virtual {
        uint256 rateChange = _rate > rate ? _rate - rate : rate - _rate;
        require((rateChange * 1e18) / rate < rateChangeLimit, "Rate: rate change over limit");

        rate = _rate;
        eraRate[_era] = rate;
    }
}
