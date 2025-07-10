// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakeManager} from "../../contracts/staking/StakeManager.sol";

// export PRIVATE_KEY=0xXXXXX
// export STAKE_MANAGER=0xXXXXX
// forge script script/staking/Config.s.sol --rpc-url https://evmrpc-testnet.0g.ai --broadcast

contract ConfigScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakeManagerAddress = vm.envAddress("STAKE_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        StakeManager(stakeManagerAddress).setEraParams(600, block.timestamp / 600);

        vm.stopBroadcast();
    }
}
