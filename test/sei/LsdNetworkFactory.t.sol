// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {StakePoolManager} from "../../contracts/base/StakePoolManager.sol";
import {StakeManager} from "../../contracts/sei/StakeManager.sol";
import {StakePool} from "../../contracts/sei/StakePool.sol";
import {LsdToken} from "../../contracts/LsdToken.sol";
import {LsdNetworkFactory} from "../../contracts/sei/LsdNetworkFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FactoryTest is Test {
    LsdNetworkFactory public factory;
    address admin = address(1);
    // string fakeValidator = "seivaloper1g4yem7u3057y0dzl366pam9zz7p3pap302srty";
    string fakeValidator = "seivaloper1kl4ca5juj8u54f8hyv45979508tr67uacazs9x";

    function setUp() public {
        StakeManager stakeManagerLogic = new StakeManager();

        StakePool stakePoolLogic = new StakePool();

        LsdNetworkFactory factoryLogic = new LsdNetworkFactory();

        factory = LsdNetworkFactory(address(new ERC1967Proxy(address(factoryLogic), "")));

        factory.initialize(admin, address(stakeManagerLogic), address(stakePoolLogic));
    }

    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount);
    event Settle(uint256 indexed era, address indexed pool);
    event Delegate(address pool, address validator, uint256 amount);

    error OutOfFund();
    error NotVoter();
    error ZeroWithdrawAmount();

    function test_create() public {
        assertEq(factory.factoryAdmin(), admin);

        string[] memory vals = new string[](1);
        vals[0] = fakeValidator;

        factory.createLsdNetwork("name", "symbol", vals);

        address lsdToken = factory.lsdTokensOfCreater(address(this))[0];
        (address stakeManagerAddr, address stakePoolAddr, address c, uint256 d) = factory.networkContractsOfLsdToken(
            lsdToken
        );

        console.log("stakeManger %s", stakeManagerAddr);
        console.log("stakePool %s", stakePoolAddr);

        address payable stakePoolAddrPayable = payable(stakePoolAddr);

        StakePool stakePool = StakePool(stakePoolAddrPayable);
        console.log("stakePool stakeManager %s", stakePool.stakeManagerAddress());

        StakeManager stakeManager = StakeManager(stakeManagerAddr);

        stakeManager.stake{value: 2e12}();

        console.log("stakePool balance %d", address(stakePool).balance);
        console.log("stakeManager latest era %d", stakeManager.latestEra());
        console.log("stakeManager current era %d", stakeManager.currentEra());

        stakeManager.setEraParams(stakeManager.eraSeconds(), stakeManager.eraOffset() - 1);

        stakeManager.newEra();
    }
}
