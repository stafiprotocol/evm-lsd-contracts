// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Ownable.sol";

abstract contract StakePoolManager is Ownable {
    // Custom errors to provide more descriptive revert messages.
    error PoolExist(address poolAddress);

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

    function addStakePool(address _poolAddress) external virtual onlyOwner {
        _addStakePool(_poolAddress);
    }

    function setMinStakeAmount(uint256 _minStakeAmount) external virtual onlyOwner {
        minStakeAmount = _minStakeAmount;
    }

    function _initStakePoolParams(address _poolAddress) internal virtual onlyInitializing {
        if (bondedPools.length() > 0) revert AlreadyInitialized();
        _addStakePool(_poolAddress);
    }

    function _addStakePool(address _poolAddress) internal virtual {
        if (_poolAddress == address(0)) revert AddressNotAllowed();
        if (!bondedPools.add(_poolAddress)) revert PoolExist(_poolAddress);
    }
}
