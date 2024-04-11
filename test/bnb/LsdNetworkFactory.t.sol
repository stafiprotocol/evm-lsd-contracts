// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {StakePoolManager} from "../../contracts/base/StakePoolManager.sol";
import {StakeManager} from "../../contracts/bnb/StakeManager.sol";
import {IStakeHub} from "../../contracts/bnb/interfaces/IStakeHub.sol";
import {StakePool} from "../../contracts/bnb/StakePool.sol";
import {LsdToken} from "../../contracts/LsdToken.sol";
import {LsdNetworkFactory} from "../../contracts/bnb/LsdNetworkFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FactoryTest is Test {
    LsdNetworkFactory public factory;
    address admin = address(1);

    address fakeValidator = 0xAf581B49EA5B09d69D86A8eD801EF0cEdA33Ae34;

    function setUp() public {
        vm.warp(39363333);
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

    // forge test --fork-url=$RPC_URL --match-test test_create --match-path ./test/bnb/LsdNetworkFactory.t.sol -vvvvv
    function test_create() public {
        assertEq(factory.factoryAdmin(), admin);
        address networkAdmin = address(100);

        address[] memory vals = new address[](1);
        vals[0] = fakeValidator;

        factory.createLsdNetwork("name", "symbol", vals, networkAdmin);

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

        // era 0
        assertEq(address(stakePool).balance, 0);
        assertEq(stakeManager.latestEra(), 0);
        assertEq(stakeManager.currentEra(), 0);
        assertEq(stakeManager.rate(), 1e18);

        vm.warp(39363333 + 86400); // time flies
        assertEq(stakeManager.currentEra(), 1);

        stakeManager.newEra();

        // era 1
        assertEq(address(stakePool).balance, 0);

        stakeManager.stake{value: 2 ether}();

        assertEq(address(stakePool).balance, 2 ether);
        assertEq(stakeManager.latestEra(), 1);
        assertEq(stakeManager.currentEra(), 1);
        assertEq(stakeManager.rate(), 1e18);

        vm.warp(39363333 + 86400 * 2); // time flies
        assertEq(stakeManager.currentEra(), 2);

        stakeManager.newEra();

        // era 2
        assertEq(address(stakePool).balance, 0);
        assertEq(stakeManager.latestEra(), 2);
        assertEq(stakeManager.currentEra(), 2);
        assertEq(stakeManager.rate(), 1e18);
    }
}
