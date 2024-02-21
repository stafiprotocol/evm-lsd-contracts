// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {StakePoolManager} from "../../contracts/base/StakePoolManager.sol";
import {StakeManager} from "../../contracts/bnb/StakeManager.sol";
import {StakePool} from "../../contracts/bnb/StakePool.sol";
import {IStaking} from "../../contracts/bnb/interfaces/IStaking.sol";
import {LsdToken} from "../../contracts/LsdToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockBnbStaking is IStaking {
    mapping(address => mapping(address => uint256)) delegated;
    mapping(address => uint256) totalDelegatedOf;

    function delegate(address validator, uint256 amount) external payable virtual {
        delegated[msg.sender][validator] = amount;
        totalDelegatedOf[msg.sender] += amount;
    }

    function undelegate(address validator, uint256 amount) external payable virtual {}

    function redelegate(address validatorSrc, address validatorDst, uint256 amount) external payable virtual {}

    function claimReward() external pure virtual returns (uint256) {
        return 0;
    }

    function claimUndelegated() external pure virtual returns (uint256) {
        return 0;
    }

    function getDelegated(address delegator, address validator) external view returns (uint256) {
        return delegated[delegator][validator];
    }

    function getTotalDelegated(address delegator) external view virtual returns (uint256) {
        return totalDelegatedOf[delegator];
    }

    function getDistributedReward(address delegator) external pure virtual returns (uint256) {
        delegator;
        return 0;
    }

    function getPendingRedelegateTime(address delegator, address valSrc, address valDst)
        external
        pure
        virtual
        returns (uint256)
    {
        delegator;
        valSrc;
        valDst;
        return 0;
    }

    function getUndelegated(address delegator) external pure virtual returns (uint256) {
        delegator;
        return 0;
    }

    function getPendingUndelegateTime(address delegator, address validator) external pure virtual returns (uint256) {
        delegator;
        validator;
        return 0;
    }

    function getRelayerFee() external pure virtual returns (uint256) {
        return 16e14;
    }

    function getMinDelegation() external pure virtual returns (uint256) {
        return 1e18;
    }

    function getRequestInFly(address delegator) external pure virtual returns (uint256[3] memory) {
        delegator;
        return [uint256(0), uint256(0), uint256(0)];
    }
}

contract StakeManagerTest is Test {
    StakeManager public manager;
    StakePool public pool;
    LsdToken public lsdToken;
    address admin;
    address fakeValidator = address(99);
    address[] voters;

    function setUp() public {
        StakeManager managerLogic = new StakeManager();
        manager = StakeManager(address(new ERC1967Proxy(address(managerLogic), "")));

        StakePool poolLogic = new StakePool();
        pool = StakePool(payable(address(new ERC1967Proxy(address(poolLogic), ""))));

        lsdToken = new LsdToken(address(manager), "rBNB", "rBNB");
        fakeValidator = address(99);
        voters = new address[](3);
        voters[0] = address(1);
        voters[1] = address(2);
        voters[2] = address(3);
        admin = address(4);
        manager.initialize(voters, 2, address(lsdToken), address(pool), fakeValidator, admin);

        assertEq(manager.owner(), admin);
        assertEq(manager.version(), 1);
        assertEq(manager.eraSeconds(), 86400);
        address[] memory bondedPools = new address[](1);
        bondedPools[0] = address(pool);
        assertEq(manager.getBondedPools(), bondedPools);
        assertEq(manager.protocolFeeCommission(), 1e17);

        pool.initialize(address(new MockBnbStaking()), address(manager), admin);
    }

    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount);
    event Settle(uint256 indexed era, address indexed pool);
    event Delegate(address pool, address validator, uint256 amount);

    error OutOfFund();
    error NotVoter();
    error ZeroWithdrawAmount();

    function test_Stake() public {
        uint256 stakeAmount = 1e18;
        vm.expectEmit(false, false, false, true);
        emit Stake(address(this), address(pool), stakeAmount, stakeAmount);
        manager.stake{value: stakeAmount + pool.getRelayerFee()}(stakeAmount);

        assertEq(lsdToken.balanceOf(address(this)), stakeAmount);
        assertEq(address(pool).balance, stakeAmount);

        StakePoolManager.PoolInfo memory info;
        {
            (uint256 a, uint256 b, uint256 c, uint256 d) = manager.poolInfoOf(address(pool));
            info = StakePoolManager.PoolInfo(a, b, c, d);
        }
        assertEq(info.era, 0);
        assertEq(info.bond, stakeAmount);
        assertEq(info.unbond, 0);
        assertEq(info.active, stakeAmount);

        // ------- settle -----
        vm.expectRevert();
        manager.settle(address(pool));

        // transfer relayer fee to pool for delegation
        (bool success,) = address(pool).call{value: 1e20}("");
        // (bool success, ) = address(pool).call{value: pool.getRelayerFee()}("");
        assertEq(success, true);

        vm.expectEmit(false, false, false, true);
        emit Delegate(address(pool), fakeValidator, stakeAmount);
        vm.expectEmit(true, true, false, true);
        emit Settle(0, address(pool));
        manager.settle(address(pool));

        address[] memory poolList = new address[](1);
        uint256[] memory rewardList = new uint256[](1);
        uint256[] memory latestTimestampList = new uint256[](1);
        poolList[0] = address(pool);
        rewardList[0] = 0;
        latestTimestampList[0] = 0;
        vm.expectRevert(NotVoter.selector);
        manager.newEra(poolList, rewardList, latestTimestampList);

        assertEq(manager.latestEra(), 0);
        vm.prank(voters[0]);
        manager.newEra(poolList, rewardList, latestTimestampList);
        assertEq(manager.latestEra(), 0);

        vm.prank(voters[1]);
        vm.warp(block.timestamp + 86400);
        manager.newEra(poolList, rewardList, latestTimestampList);
        assertEq(manager.latestEra(), 1);

        vm.prank(voters[2]);
        manager.newEra(poolList, rewardList, latestTimestampList);
        assertEq(manager.latestEra(), 1);

        uint256 withdrawalRelayerFee = manager.getWithdrawalRelayerFee();
        vm.expectRevert(ZeroWithdrawAmount.selector);
        manager.withdraw{value: withdrawalRelayerFee}();
    }
}
