// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {StakePoolManager} from "../../contracts/base/StakePoolManager.sol";
import {StakeManager} from "../../contracts/sei/StakeManager.sol";
import {IGovDistribution} from "../../contracts/sei/interfaces/IGovDistribution.sol";
import {IGovStaking} from "../../contracts/sei/interfaces/IGovStaking.sol";
import {StakePool} from "../../contracts/sei/StakePool.sol";
import {LsdToken} from "../../contracts/LsdToken.sol";
import {LsdNetworkFactory} from "../../contracts/sei/LsdNetworkFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockSeiGov is IGovDistribution, IGovStaking {
    receive() external payable{}

    function withdrawDelegationRewards(string memory validator) external returns (bool success) {
        return true;
    }

    function delegate(string memory valAddress, uint256 amount) external returns (bool success) {
        return true;
    }

    function redelegate(
        string memory srcAddress,
        string memory dstAddress,
        uint256 amount
    ) external returns (bool success) {
        return true;
    }

    function undelegate(string memory valAddress, uint256 amount) external returns (bool success) {
        return true;
    }
}

contract MockStakePool is StakePool {
    IGovDistribution govDistribution;
    IGovStaking govStaking;

    function setSeiGov(address _govStaking, address _govDistribution) external {
        govDistribution = IGovDistribution(_govDistribution);
        govStaking = IGovStaking(_govStaking);
    }

    function _govDelegate(string memory validator, uint256 amount) internal override {
        govStaking.delegate(validator, amount);
        address(govStaking).call{value: amount*1e12}("");
    }
    function _govUndelegate(string memory validator, uint256 amount) internal override {
        govStaking.undelegate(validator, amount);
    }
    function _govRedelegate(string memory srcValidator,string memory dstValidator, uint256 amount) internal override {
        govStaking.redelegate(srcValidator, dstValidator, amount);
    }
    function _govWithdrawRewards(string memory validator) internal override {
        govDistribution.withdrawDelegationRewards(validator);
    }
}

contract FactoryTest is Test {
    LsdNetworkFactory public factory;
    address admin = address(1);
    // string fakeValidator = "seivaloper1g4yem7u3057y0dzl366pam9zz7p3pap302srty";
    string fakeValidator = "seivaloper1kl4ca5juj8u54f8hyv45979508tr67uacazs9x";

    function setUp() public {
        vm.warp(1710201600);
        StakeManager stakeManagerLogic = new StakeManager();

        StakePool stakePoolLogic = new MockStakePool();

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
        address networkAdmin = address(100);

        string[] memory vals = new string[](1);
        vals[0] = fakeValidator;

        factory.createLsdNetwork("name", "symbol", vals, networkAdmin);

        address lsdToken = factory.lsdTokensOfCreater(address(this))[0];
        (address stakeManagerAddr, address stakePoolAddr, address c, uint256 d) = factory.networkContractsOfLsdToken(
            lsdToken
        );

        console.log("stakeManger %s", stakeManagerAddr);
        console.log("stakePool %s", stakePoolAddr);

        address payable stakePoolAddrPayable = payable(stakePoolAddr);

        MockStakePool stakePool = MockStakePool(stakePoolAddrPayable);
        address mockSeiGov = address(new MockSeiGov());
        stakePool.setSeiGov(mockSeiGov, mockSeiGov);
        console.log("stakePool stakeManager %s", stakePool.stakeManagerAddress());

        StakeManager stakeManager = StakeManager(stakeManagerAddr);

        stakeManager.stake{value: 2e12}();

        assertEq(address(stakePool).balance, 2e12);
        assertEq(stakeManager.latestEra(), 0);
        assertEq(stakeManager.currentEra(), 0);
        
        vm.warp(1710201600+86400); // time flies
        assertEq(stakeManager.currentEra(), 1);
        stakeManager.newEra();

        assertEq(address(stakePool).balance, 0);
        assertEq(stakeManager.latestEra(), 1);
    }
}
