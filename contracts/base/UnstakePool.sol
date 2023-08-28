pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Ownable.sol";

abstract contract UnstakePool is Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    struct UnstakeInfo {
        uint256 era;
        address pool;
        address receiver;
        uint256 amount;
    }

    uint256 public constant UNSTAKE_TIMES_LIMIT = 100;
    uint256 public constant MAX_UNBONDING_DURATION = 32;

    uint256 public unbondingDuration;

    // unstake info
    uint256 public nextUnstakeIndex;
    mapping(uint256 => UnstakeInfo) public unstakeAtIndex;
    mapping(address => EnumerableSet.UintSet) unstakesOfUser;

    event SetUnbondingDuration(uint256 unbondingDuration);

    function getUnstakeIndexListOf(address _staker) public view virtual returns (uint256[] memory unstakeIndexList) {
        unstakeIndexList = new uint256[](unstakesOfUser[_staker].length());
        for (uint256 i = 0; i < unstakesOfUser[_staker].length(); ++i) {
            unstakeIndexList[i] = unstakesOfUser[_staker].at(i);
        }
        return unstakeIndexList;
    }

    function setUnbondingDuration(uint256 _unbondingDuration) public virtual onlyOwner {
        _setUnbondingDuration(_unbondingDuration);
    }

    function _initUnstakeParams(uint256 _unbondingDuration) internal virtual {
        require(_unbondingDuration == 0, "Unstake: already init");
        _setUnbondingDuration(_unbondingDuration);
    }

    function _setUnbondingDuration(uint256 _unbondingDuration) internal virtual {
        require(_unbondingDuration > 0, "Unstake: zero unbonding duration");
        require(_unbondingDuration <= MAX_UNBONDING_DURATION, "Unstake: max unbonding duration limit");

        unbondingDuration = _unbondingDuration;
        emit SetUnbondingDuration(_unbondingDuration);
    }
}
