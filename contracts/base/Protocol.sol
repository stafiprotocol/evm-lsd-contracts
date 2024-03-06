// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Ownable.sol";

abstract contract Protocol is Ownable {
    // Custom errors to provide more descriptive revert messages.
    error GreaterThanMaxProtocolFeeCommission(uint256 protocolFeeCommission);

    using SafeERC20 for IERC20;

    uint256 public constant MAX_PROTOCOL_FEE_COMMISSION = 2 * 1e17;

    address public lsdToken;
    uint256 public protocolFeeCommission;
    uint256 public totalProtocolFee;

    function withdrawProtocolFee(address _to) external virtual onlyOwner {
        IERC20(lsdToken).safeTransfer(_to, IERC20(lsdToken).balanceOf(address(this)));
    }

    function setProtocolFeeCommission(uint256 _protocolFeeCommission) external virtual onlyOwner {
        if (_protocolFeeCommission > MAX_PROTOCOL_FEE_COMMISSION)
            revert GreaterThanMaxProtocolFeeCommission(_protocolFeeCommission);

        protocolFeeCommission = _protocolFeeCommission;
    }

    function _initProtocolParams(address _lsdToken) internal virtual onlyInitializing {
        if (protocolFeeCommission != 0) revert AlreadyInitialized();
        if (_lsdToken == address(0)) revert AddressNotAllowed();

        lsdToken = _lsdToken;
        protocolFeeCommission = 1e17;
    }
}
