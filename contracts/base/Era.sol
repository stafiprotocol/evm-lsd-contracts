pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Ownable.sol";

abstract contract Era is Ownable {
    uint256 public constant MIN_ERA_SECONDS = 3600;
    uint256 public constant MAX_ERA_SECONDS = 172800;

    uint256 public eraSeconds;
    uint256 public eraOffset;

    uint256 public latestEra;

    function currentEra() public view virtual returns (uint256) {
        return block.timestamp / eraSeconds - eraOffset;
    }

    function setEraParams(uint256 _eraSeconds, uint256 _eraOffset) public virtual onlyOwner {
        require(eraSeconds != 0, "Era: not init");
        require(_eraSeconds >= MIN_ERA_SECONDS, "Era: min era seconds limit");
        require(_eraSeconds <= MAX_ERA_SECONDS, "Era: max era seconds limit");
        require(currentEra() == block.timestamp / _eraSeconds - _eraOffset, "Era: wrong era parameters");

        eraSeconds = _eraSeconds;
        eraOffset = _eraOffset;
    }

    function _initEraParams() internal virtual {
        require(eraSeconds == 0, "Era: already init");

        eraSeconds = 86400;
        eraOffset = block.timestamp / eraSeconds;
    }
}
