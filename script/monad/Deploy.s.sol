// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakePool} from "../../contracts/monad/StakePool.sol";
import {StakeManager} from "../../contracts/monad/StakeManager.sol";
import {LsdNetworkFactory} from "../../contracts/monad/LsdNetworkFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// export PRIVATE_KEY=0xXXXXX
// forge script script/monad/Deploy.s.sol --rpc-url https://rpc-testnet.monadinfra.com --broadcast

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        address admin = vm.addr(deployerPrivateKey);

        StakePool stakePoolLogic = new StakePool();
        StakeManager stakeManagerLogic = new StakeManager();
        LsdNetworkFactory lsdNetworkFactoryLogic = new LsdNetworkFactory();

        ERC1967Proxy lsdNetworkFactoryProxy = new ERC1967Proxy(address(lsdNetworkFactoryLogic), "");

        LsdNetworkFactory(address(lsdNetworkFactoryProxy)).initialize(
            admin, address(stakeManagerLogic), address(stakePoolLogic)
        );

        console.log("LsdNetworkFactory Proxy deployed at:", address(lsdNetworkFactoryProxy));

        vm.stopBroadcast();
    }
}
