// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {StakePool} from "../../contracts/monad/StakePool.sol";

// export PRIVATE_KEY=0xXXXXX
// export STAKE_POOL_PROXY=0xXXXXX
// forge script script/monad/Upgrade.s.sol --rpc-url https://rpc-testnet.monadinfra.com --broadcast

interface IUpgradeable {
    function upgradeTo(address newImplementation) external;
}

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakePool newStakePoolLogic = new StakePool();

        address stakePoolProxyAddr = vm.envAddress("STAKE_POOL_PROXY");

        IUpgradeable(stakePoolProxyAddr).upgradeTo(address(newStakePoolLogic));

        console.log("StakePool upgraded to:", address(newStakePoolLogic));

        vm.stopBroadcast();
    }
}
