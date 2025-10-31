// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakeManager} from "../../contracts/monad/StakeManager.sol";

// export PRIVATE_KEY=0xXXXXX
// export STAKE_MANAGER_PROXY=0xXXXXX
// forge script script/monad/UpgradeStakeManager.s.sol --rpc-url https://rpc-testnet.monadinfra.com --broadcast

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract UpgradeStakeManagerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakeManager newStakePoolLogic = new StakeManager();

        address stakeManagerProxyAddr = vm.envAddress("STAKE_MANAGER_PROXY");

        IUpgradeable(stakeManagerProxyAddr).upgradeTo(address(newStakePoolLogic));

        console.log("StakeManager upgraded to:", address(newStakePoolLogic));

        vm.stopBroadcast();
    }
}
