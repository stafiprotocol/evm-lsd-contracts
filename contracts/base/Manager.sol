pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Era.sol";
import "./Rate.sol";
import "./StakePool.sol";
import "./UnstakePool.sol";
import "./Protocol.sol";

abstract contract Manager is Era, Rate, StakePool, UnstakePool, Protocol {
    using SafeERC20 for IERC20;

    address public delegationBalancer;
    address public lsdToken;

    modifier onlyDelegationBalancer() {
        require(delegationBalancer == msg.sender, "caller is not delegation balancer");
        _;
    }

    function transferDelegationBalancer(address _newDelegationBalancer) public virtual onlyOwner {
        require(_newDelegationBalancer != address(0), "zero address");
        delegationBalancer = _newDelegationBalancer;
    }

    function withdrawProtocolFee(address _to) public virtual onlyOwner {
        IERC20(lsdToken).safeTransfer(_to, IERC20(lsdToken).balanceOf(address(this)));
    }

    function _initManagerParams(
        address _lsdToken,
        address _poolAddress,
        uint256 _unbondingDuration,
        uint256 _rateChangeLimit
    ) internal virtual {
        require(_lsdToken != address(0), "zero token address");

        _initEraParams();
        _initRateParams(_rateChangeLimit);
        _initStakePoolParams(_poolAddress);
        _initUnstakeParams(_unbondingDuration);
        _initProtocolParams();

        lsdToken = _lsdToken;
        delegationBalancer = msg.sender;
    }
    
}
