pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface Errors {
    error NotInitialized();
    error AddressNotAllowed();
    error AlreadyInitialized();

    error NotFactoryAdmin();
    error FailedToCall();
}
