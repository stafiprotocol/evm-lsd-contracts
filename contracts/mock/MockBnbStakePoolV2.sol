pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "../bnb/StakePool.sol";

contract MockBnbStakePoolV2 is StakePool {
    string public v2var;

    function initV2(string calldata _msg, address _newStakingAddress) public reinitializer(2) {
        v2var = _msg;
        stakingAddress = _newStakingAddress;
    }
}
