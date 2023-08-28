pragma solidity 0.8.19;

// SPDX-License-Identifier: LGPL-3.0-only

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Proxy is TransparentUpgradeableProxy {
    constructor(
        address _proxyTo,
        address admin_,
        bytes memory _data
    ) TransparentUpgradeableProxy(_proxyTo, admin_, _data) {}
}
