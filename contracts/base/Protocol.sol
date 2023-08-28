pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Ownable.sol";

abstract contract Protocol is Ownable {
    uint256 public constant MAX_PROTOCOL_FEE_COMMISSION = 2 * 1e17;

    uint256 public protocolFeeCommission;
    uint256 public totalProtocolFee;

    function setProtocolFee(uint256 _protocolFeeCommission) public virtual onlyOwner {
        require(_protocolFeeCommission <= MAX_PROTOCOL_FEE_COMMISSION, "Protocol: max protocol fee limit");

        protocolFeeCommission = _protocolFeeCommission;
    }

    function _initProtocolParams() internal virtual {
        require(protocolFeeCommission == 0, "Protocol: already init");

        protocolFeeCommission = 1e17;
    }
}
