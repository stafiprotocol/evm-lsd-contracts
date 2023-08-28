pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Ownable.sol";

abstract contract StakePool is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PoolInfo {
        uint256 era;
        uint256 bond;
        uint256 unbond;
        uint256 active;
    }

    uint256 public minStakeAmount;

    EnumerableSet.AddressSet bondedPools;
    mapping(address => PoolInfo) public poolInfoOf;

    function getBondedPools() public view virtual returns (address[] memory pools) {
        pools = new address[](bondedPools.length());
        for (uint256 i = 0; i < bondedPools.length(); ++i) {
            pools[i] = bondedPools.at(i);
        }
        return pools;
    }

    function addStakePool(address _poolAddress) public virtual onlyOwner {
        _addStakePool(_poolAddress);
    }

    function setMinStakeAmount(uint256 _minStakeAmount) public virtual onlyOwner {
        minStakeAmount = _minStakeAmount;
    }

    function _initStakePoolParams(address _poolAddress) internal virtual {
        require(bondedPools.length() == 0, "StakePool: already init");
        _addStakePool(_poolAddress);
    }

    function _addStakePool(address _poolAddress) internal virtual {
        require(_poolAddress != address(0), "zero pool address");
        require(bondedPools.add(_poolAddress), "pool exist");
    }
}
