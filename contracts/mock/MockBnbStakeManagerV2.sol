pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "../bnb/StakeManager.sol";

contract MockBnbStakeManagerV2 is StakeManager {
    string public v2var;

    function initV2(string calldata _msg, uint256 _newProtocolFee) public reinitializer(2) {
        v2var = _msg;
        protocolFeeCommission = _newProtocolFee;
    }
}