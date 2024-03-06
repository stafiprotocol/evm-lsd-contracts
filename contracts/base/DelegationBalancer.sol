// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./Ownable.sol";

abstract contract DelegationBalancer is Ownable {
    // Custom errors to provide more descriptive revert messages.
    error NotDelegationBalancer();

    address public delegationBalancer;

    modifier onlyDelegationBalancer() {
        if (delegationBalancer != msg.sender) revert NotDelegationBalancer();
        _;
    }

    function transferDelegationBalancer(address _newDelegationBalancer) external virtual onlyOwner {
        if (_newDelegationBalancer == address(0)) revert AddressNotAllowed();
        delegationBalancer = _newDelegationBalancer;
    }

    function _initDelegationBalancer() internal virtual onlyInitializing {
        if (delegationBalancer != address(0)) revert AlreadyInitialized();
        delegationBalancer = msg.sender;
    }
}
