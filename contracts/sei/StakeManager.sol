pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/ISeiStakePool.sol";
import "../LsdToken.sol";
import "./StakePool.sol";

contract StakeManager is Initializable, UUPSUpgradeable {
    // Custom errors to provide more descriptive revert messages.
    error ZeroStakeTokenAddress();
    error NotAuthorized();
    error PoolNotEmpty();
    error DelegateNotEmpty();
    error PoolNotExist(address poolAddress);
    error ValidatorNotExist();
    error ValidatorDuplicated();
    error EntrustedPoolDuplicated();
    error ZeroRedelegateAmount();
    error NotEnoughStakeAmount();
    error ZeroUnstakeAmount();
    error ZeroWithdrawAmount();
    error UnstakeTimesExceedLimit();
    error AlreadyWithdrawed();
    error EraNotMatch();
    error NotEnoughAmountToUndelegate();
    error FailedToCall();

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant DEFAULT_ERA_SECONDS = 86400;

    struct StackInfo {
        address admin;
        address stackFeeReceiver;
        address govStakingAddr;
        address govDistributionAddr;
        uint256 stackFeeCommission;
        uint256 totalStackFee;
        address[] entrustedPools;
        uint8 unbondingPeriod;
    }

    struct PoolInfo {
        address admin;
        address lsdToken;
        address platformFeeReceiver;
        uint256 era;
        uint256 rate;
        uint256 bond;
        uint256 unbond;
        uint256 active;
        uint256 eraSeconds;
        int256 offset;
        uint256 minimalStake;
        uint256 nextUnstakeIndex;
        uint256 platformFeeCommission;
        uint256 totalPlatformFee;
        uint256 totalLsdTokenAmount;
        uint256 rateChangeLimit;
        string[] validators;
        uint8 unbondingPeriod;
        uint8 unstakeTimesLimit;
        bool paused;
    }

    address public stakePoolLogicAddress;
    StackInfo public stackInfo;
    mapping(address => PoolInfo) public getPoolInfo;

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
        if (msg.sender != stackInfo.admin) {
            revert NotAuthorized();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stackFeeReceiver,
        address _govStakingAddr,
        address _govDistributionAddr,
        uint8 _unbondingPeriod,
        address _admin
    ) external virtual initializer {
        stackInfo = StackInfo({
            admin: _admin,
            govStakingAddr: _govStakingAddr,
            govDistributionAddr: _govDistributionAddr,
            stackFeeReceiver: _stackFeeReceiver,
            stackFeeCommission: 1e17,
            totalStackFee: 0,
            unbondingPeriod: _unbondingPeriod,
            entrustedPools: new address[](0)
        });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyStackAdmin {}

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function configStack(
        address _stackFeeReceiver,
        uint256 _stackFeeCommission,
        address _addEntrustedPool,
        address _removeEntrustedPool
    ) external onlyStackAdmin {
        if (_stackFeeReceiver != address(0)) {
            stackInfo.stackFeeReceiver = _stackFeeReceiver;
        }

        if (_stackFeeCommission != 0) {
            stackInfo.stackFeeCommission = _stackFeeCommission;
        }

        if (_addEntrustedPool != address(0)) {
            for (uint256 i = 0; i < stackInfo.entrustedPools.length; i++) {
                if (stackInfo.entrustedPools[i] == _addEntrustedPool) {
                    revert EntrustedPoolDuplicated();
                }
            }
            stackInfo.entrustedPools.push(_addEntrustedPool);
        }

        if (_removeEntrustedPool != address(0)) {
            for (uint256 i = 0; i < stackInfo.entrustedPools.length; i++) {
                if (stackInfo.entrustedPools[i] == _removeEntrustedPool) {
                    stackInfo.entrustedPools[i] = stackInfo.entrustedPools[stackInfo.entrustedPools.length - 1];
                    stackInfo.entrustedPools.pop();
                }
            }
        }
    }

    // --------- platform ----------

    struct InitPoolParams {
        string lsdTokenName;
        string lsdTokenSymbol;
        uint256 minimalStake;
        uint256 platformFeeCommission;
        address platformFeeReceiver;
        string[] validators;
    }

    function initPool(InitPoolParams memory params) external {
        address lsdToken = address(new LsdToken(address(this), params.lsdTokenName, params.lsdTokenSymbol));
        address stakePool = deploy(stakePoolLogicAddress);
        (bool success, ) = stakePool.call(
            abi.encodeWithSelector(StakePool.initialize.selector, address(this), stackInfo.govStakingAddr, msg.sender)
        );
        if (!success) {
            revert FailedToCall();
        }

        int256 offset = 0 - int256(block.timestamp / DEFAULT_ERA_SECONDS);

        getPoolInfo[stakePool] = PoolInfo({
            admin: msg.sender,
            lsdToken: lsdToken,
            platformFeeReceiver: params.platformFeeReceiver,
            era: 0,
            rate: 0,
            bond: 0,
            unbond: 0,
            active: 0,
            eraSeconds: DEFAULT_ERA_SECONDS,
            offset: offset,
            minimalStake: params.minimalStake,
            nextUnstakeIndex: 0,
            platformFeeCommission: params.platformFeeCommission,
            totalPlatformFee: 0,
            totalLsdTokenAmount: 0,
            rateChangeLimit: 0,
            validators: params.validators,
            unbondingPeriod: stackInfo.unbondingPeriod,
            unstakeTimesLimit: 20,
            paused: false
        });
    }

    // --------- helper ----------

    function deploy(address _logicAddress) private returns (address) {
        return address(new ERC1967Proxy(_logicAddress, ""));
    }
}
