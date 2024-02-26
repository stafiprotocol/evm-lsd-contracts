pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./StakePool.sol";
import "./libraries/NewContract.sol";
import "./libraries/Pool.sol";
import "./libraries/Stack.sol";

contract StakeManager is Initializable, UUPSUpgradeable {
    // Custom errors to provide more descriptive revert messages.
    error ZeroStakeTokenAddress();
    error NotAuthorized();
    error PoolNotEmpty();
    error DelegateNotEmpty();
    error PoolNotExist(address poolAddress);
    error ValidatorNotExist();
    error ValidatorDuplicated();
    error ZeroRedelegateAmount();
    error NotEnoughStakeAmount();
    error ZeroUnstakeAmount();
    error ZeroWithdrawAmount();
    error UnstakeTimesExceedLimit();
    error AlreadyWithdrawed();
    error EraNotMatch();
    error NotEnoughAmountToUndelegate();
    error FailedToCall();

    using Pool for Pool.State;
    using Stack for Stack.State;

    address public stakePoolLogicAddress;

    Stack.State public stackState;
    mapping(address => Pool.State) public getPoolState;

    // events
    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount);
    event Unstake(
        address staker,
        address poolAddress,
        uint256 tokenAmount,
        uint256 lsdTokenAmount,
        uint256 unstakeIndex
    );
    event Withdraw(address staker, address poolAddress, uint256 tokenAmount, int256[] unstakeIndexList);
    event ExecuteNewEra(uint256 indexed era, uint256 rate);
    event Delegate(address pool, string validator, uint256 amount);
    event Undelegate(address pool, string validator, uint256 amount);
    event NewReward(address pool, uint256 amount);

    modifier onlyStackAdmin() {
        if (msg.sender != stackState.admin) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyPoolAdmin(address _poolAddress) {
        if (msg.sender != getPoolState[_poolAddress].admin) {
            revert NotAuthorized();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(Stack.InitParams memory params) external virtual initializer {
        stackState.init(params);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyStackAdmin {}

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function configStack(Stack.ConfigStackParams memory _params) external onlyStackAdmin {
        stackState.configStack(_params);
    }

    // --------- platform ----------
    function initPool(Pool.InitParams memory _params) external {
        address lsdToken = NewContract.newLsdToken(address(this), _params.lsdTokenName, _params.lsdTokenSymbol);
        address stakePool = NewContract.newERC1967Proxy(stakePoolLogicAddress);

        (bool success, ) = stakePool.call(
            abi.encodeWithSelector(StakePool.initialize.selector, address(this), stackState.govStakingAddr, msg.sender)
        );
        if (!success) {
            revert FailedToCall();
        }

        getPoolState[stakePool].init(_params, lsdToken, stakePool, stackState.unbondingSeconds);
    }

    function configPool(
        address _poolAddress,
        Pool.ConfigPoolParams memory _params
    ) external onlyPoolAdmin(_poolAddress) {
        getPoolState[_poolAddress].configPool(_params, stackState.unbondingSeconds);
    }

    function redelegate(
        address _poolAddress,
        string memory _srcValidator,
        string memory _dstValidator,
        uint256 _amount
    ) external onlyPoolAdmin(_poolAddress) {
        getPoolState[_poolAddress].redelegate(_srcValidator, _dstValidator, _amount);
    }

    // --------- user ----------
    function stake(address _poolAddress, uint256 _stakeAmount) external payable {
        getPoolState[_poolAddress].stake(_stakeAmount);
    }

    function unstake(address _poolAddress, uint256 _lsdTokenAmount) external {
        getPoolState[_poolAddress].unstake(_lsdTokenAmount);
    }

    function withdraw(address _poolAddress) external {
        getPoolState[_poolAddress].withdraw();
    }

    // --------- permissionless ----------

    function newEra(address _poolAddress) external {
        getPoolState[_poolAddress].newEra();
    }
}
