pragma solidity 0.8.19;

// SPDX-License-Identifier: LGPL-3.0-only

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OzProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}
}
