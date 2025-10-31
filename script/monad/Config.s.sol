// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakeManager} from "../../contracts/monad/StakeManager.sol";

// export PRIVATE_KEY=0xXXXXX
// export STAKE_MANAGER=0xXXXXX
// forge script script/monad/Config.s.sol --rpc-url https://rpc-testnet.monadinfra.com --broadcast

contract ConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakeManagerAddress = vm.envAddress("STAKE_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        uint256 eraSeconds = 600;
        StakeManager(stakeManagerAddress).setEraParams(eraSeconds, block.timestamp / eraSeconds);

        vm.stopBroadcast();
    }
}
