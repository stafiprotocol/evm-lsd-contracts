// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IMaticStakePool.sol";
import "../interfaces/ILsdToken.sol";
import "../base/Manager.sol";

contract StakeManager is Initializable, Manager, UUPSUpgradeable {
    // Custom errors to provide more descriptive revert messages.
    error ZeroStakeTokenAddress();
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

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    address public stakeTokenAddress;

    mapping(address => EnumerableSet.UintSet) validatorIdsOf;
    // pool => validator Id => max claimed nonce
    mapping(address => mapping(uint256 => uint256)) public maxClaimedNonceOf;

    // events
    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount);
    event Unstake(
        address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount, uint256 unstakeIndex
    );
    event Withdraw(address staker, address poolAddress, uint256 tokenAmount, int256[] unstakeIndexList);
    event ExecuteNewEra(uint256 indexed era, uint256 rate);
    event Delegate(address pool, uint256 validator, uint256 amount);
    event Undelegate(address pool, uint256 validator, uint256 amount);
    event NewReward(address pool, uint256 amount);
    event NewClaimedNonce(address pool, uint256 validator, uint256 nonce);
    event ServiceTerminated();
    event UnstakeAndWithdraw(address staker, address poolAddress, uint256 lsdTokenAmount, uint256 tokenAmount);
    event AdminWithdraw(address admin, address poolAddress, uint256 tokenAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _lsdToken,
        address _stakeTokenAddress,
        address _poolAddress,
        uint256 _validatorId,
        address _owner,
        address _factoryAddress
    ) external virtual initializer {
        if (_stakeTokenAddress == address(0)) revert ZeroStakeTokenAddress();

        _transferOwnership(_owner);
        _initManagerParams(_lsdToken, _poolAddress, _factoryAddress, 4, 0);

        validatorIdsOf[_poolAddress].add(_validatorId);
        stakeTokenAddress = _stakeTokenAddress;

        IMaticStakePool(_poolAddress).approveForStakeManager(stakeTokenAddress, 1e28);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getValidatorIdsOf(address _poolAddress) public view returns (uint256[] memory validatorIds) {
        validatorIds = new uint256[](validatorIdsOf[_poolAddress].length());
        for (uint256 i = 0; i < validatorIdsOf[_poolAddress].length(); ++i) {
            validatorIds[i] = validatorIdsOf[_poolAddress].at(i);
        }
        return validatorIds;
    }

    // ------------ settings ------------

    function terminateService() external onlyOwner {
        _manualUndelegateAll();
        emit ServiceTerminated();
    }

    function adminWithdraw(address _poolAddress, uint256 _amount) external onlyOwner {
        IMaticStakePool(_poolAddress).withdrawForStaker(stakeTokenAddress, msg.sender, _amount);
        emit AdminWithdraw(msg.sender, _poolAddress, _amount);
    }

    function unstakeClaimTokens(address _poolAddress) external onlyOwner {
        uint256[] memory validators = getValidatorIdsOf(_poolAddress);
        for (uint256 j = 0; j < validators.length; ++j) {
            uint256 oldClaimedNonce = maxClaimedNonceOf[_poolAddress][validators[j]];
            uint256 newClaimedNonce = IMaticStakePool(_poolAddress).unstakeClaimTokens(validators[j], oldClaimedNonce);
            maxClaimedNonceOf[_poolAddress][validators[j]] = newClaimedNonce;
            if (newClaimedNonce > oldClaimedNonce) {
                emit NewClaimedNonce(_poolAddress, validators[j], newClaimedNonce);
            }
        }
    }

    function _manualUndelegateAll() internal {
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];

            uint256[] memory validators = getValidatorIdsOf(poolAddress);
            IMaticStakePool(poolAddress).checkAndWithdrawRewards(validators);
            uint256 totalStaked = 0;
            for (uint256 j = 0; j < validators.length; ++j) {
                uint256 stakedAmount = IMaticStakePool(poolAddress).getDelegated(validators[j]);
                if (stakedAmount > 0) {
                    IMaticStakePool(poolAddress).undelegate(validators[j], stakedAmount);
                    emit Undelegate(poolAddress, validators[j], stakedAmount);
                }
                totalStaked = totalStaked + stakedAmount;
            }
            if (totalStaked > 0) {
                IMaticStakePool(poolAddress).approveForStakeManager(stakeTokenAddress, totalStaked);
            }
        }
    }

    // ----- staker operation

    function unstakeAndWithdrawAll() external {
        uint256 _lsdTokenAmount = IERC20(lsdToken).balanceOf(msg.sender);
        if (_lsdTokenAmount == 0) revert ZeroUnstakeAmount();
        
        address _poolAddress = bondedPools.at(0);

        uint256 tokenAmount = (_lsdTokenAmount * rate) / EIGHTEEN_DECIMALS;

        // burn lsdToken
        ERC20Burnable(lsdToken).burnFrom(msg.sender, _lsdTokenAmount);

        IMaticStakePool(_poolAddress).withdrawForStaker(stakeTokenAddress, msg.sender, tokenAmount);

        emit UnstakeAndWithdraw(msg.sender, _poolAddress, _lsdTokenAmount, tokenAmount);
    }
}
