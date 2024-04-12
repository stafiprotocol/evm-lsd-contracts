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

    address fakeValidator1 = 0xAf581B49EA5B09d69D86A8eD801EF0cEdA33Ae34;
    address fakeValidator2 = 0x696606f04f7597F444265657C8c13039Fd759b14;
    address fakeValidator3 = 0x341e228f22D4ec16297DD05A9d6347C74c125F66;
    address[] vals = [fakeValidator1, fakeValidator2, fakeValidator3];

    IStakeHub stakeHub = IStakeHub(0x0000000000000000000000000000000000002002);

    receive() external payable {}

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

    // forge test --fork-url=$BSC_TESTNET_RPC_URL --match-test test_create --match-path ./test/bnb/LsdNetworkFactory.t.sol -vvvvv
    function test_create() public {
        assertEq(factory.factoryAdmin(), admin);
        address networkAdmin = address(this);

        factory.createLsdNetwork("name", "symbol", vals, networkAdmin);

        address lsdTokenAddr = factory.lsdTokensOfCreater(address(this))[0];
        LsdToken lsdToken = LsdToken(lsdTokenAddr);
        (address stakeManagerAddr, address stakePoolAddr, , ) = factory.networkContractsOfLsdToken(lsdTokenAddr);

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

        stakeManager.stake{value: 4 ether}();

        assertEq(lsdToken.balanceOf(address(this)), 4 ether);

        assertEq(address(stakePool).balance, 4 ether);
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

        lsdToken.approve(stakeManagerAddr, 4 ether);
        stakeManager.unstake(2 ether);

        assertEq(lsdToken.balanceOf(address(this)), 2 ether);

        for (uint256 i = 3; i <= 10; ++i) {
            vm.warp(39363333 + 86400 * i); // time flies
            assertEq(stakeManager.currentEra(), i);

            stakeManager.newEra();
        }

        // era 10
        assertEq(stakeManager.latestEra(), 10);
        assertEq(stakeManager.currentEra(), 10);
        assertEq(stakeManager.rate(), 1e18);

        assertEq(address(stakePool).balance, 2 ether);
        uint256 preBalance = address(this).balance;

        stakeManager.withdraw();

        uint256 postBalance = address(this).balance;
        assertEq(address(stakePool).balance, 0);
        assertEq(postBalance - preBalance, 2 ether);

        uint256 redelegateAmount = 1.2 ether;
        stakeManager.redelegate{
            value: (redelegateAmount * stakeHub.redelegateFeeRate()) / stakeHub.REDELEGATE_FEE_RATE_BASE()
        }(stakePoolAddr, fakeValidator1, fakeValidator2, redelegateAmount);

        console.log("pending delegate: %d", stakePool.pendingDelegate());

        vm.warp(39363333 + 86400 * 11); // time flies
        assertEq(stakeManager.currentEra(), 11);

        stakeManager.newEra();

        console.log("pending delegate: %d", stakePool.pendingDelegate());
        console.log("total delegate: %d", stakePool.getTotalDelegated(vals));
        // era 11
        assertEq(stakeManager.latestEra(), 11);
        assertEq(stakeManager.currentEra(), 11);
        assertEq(stakeManager.rate(), 1e18);
    }
}
