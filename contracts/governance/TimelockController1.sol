pragma solidity 0.8.19;

// SPDX-License-Identifier: LGPL-3.0-only

import { TimelockController as OZTimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimelockController1 is OZTimelockController {
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin) 
    OZTimelockController( minDelay,  proposers,  executors, admin) {}
}
