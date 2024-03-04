// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {StakePoolManager} from "../../contracts/base/StakePoolManager.sol";
import {StakeManager} from "../../contracts/sei/StakeManager.sol";
import {StakePool} from "../../contracts/sei/StakePool.sol";
import {WithdrawPool} from "../../contracts/sei/WithdrawPool.sol";
import {LsdToken} from "../../contracts/LsdToken.sol";
import {LsdNetworkFactory} from "../../contracts/sei/LsdNetworkFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract StakeManagerTest is Test {
    LsdNetworkFactory public factory;
    address admin = address(1);
    string fakeValidator = "seivaloper1g4yem7u3057y0dzl366pam9zz7p3pap302srty";

    function setUp() public {
        StakeManager stakeManagerLogic = new StakeManager();

        StakePool stakePoolLogic = new StakePool();

        WithdrawPool withdrawPoolLogic = new WithdrawPool();

        LsdNetworkFactory factoryLogic = new LsdNetworkFactory();
        factory = LsdNetworkFactory(address(new ERC1967Proxy(address(factoryLogic), "")));

        factory.initialize(
            admin,
            admin,
            admin,
            address(stakeManagerLogic),
            address(stakePoolLogic),
            address(withdrawPoolLogic)
        );
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
    }
}
