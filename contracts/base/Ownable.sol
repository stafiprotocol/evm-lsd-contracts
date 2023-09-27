pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "./Errors.sol";

abstract contract Ownable is Errors {
    error NotOwner();

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (owner() != msg.sender) revert NotOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address _newOwner) external virtual onlyOwner {
        if (_newOwner == address(0)) revert AddressNotAllowed();
        _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address _newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }
}