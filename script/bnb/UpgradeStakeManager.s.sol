// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakeManager} from "../../contracts/bnb/StakeManager.sol";

// export PRIVATE_KEY=0xXXXXX
// export STAKE_MANAGER_PROXY=0xXXXXX
// forge script script/bnb/UpgradeStakeManager.s.sol --rpc-url <BSC_RPC_URL> --broadcast

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract UpgradeBnbStakeManagerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakeManager newStakeManagerLogic = new StakeManager();

        address stakeManagerProxyAddr = vm.envAddress("STAKE_MANAGER_PROXY");

        IUpgradeable(stakeManagerProxyAddr).upgradeTo(address(newStakeManagerLogic));

        console.log("BNB StakeManager upgraded to:", address(newStakeManagerLogic));

        vm.stopBroadcast();
    }
}
