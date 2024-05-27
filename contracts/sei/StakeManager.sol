// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/ISeiStakePool.sol";
import "../interfaces/ILsdToken.sol";
import "../base/Manager.sol";
import "./libraries/EnumerableStringSet.sol";

contract StakeManager is Initializable, Manager, UUPSUpgradeable {
    // Custom errors to provide more descriptive revert messages.
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
    error UnstakeNotOpen();

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableStringSet for EnumerableStringSet.StringSet;

    uint256 constant TWELVE_DECIMALS = 1e12;

    mapping(address => EnumerableStringSet.StringSet) validatorsOf;
    bool public unstakeSwitch;

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
    event Delegate(address pool, string[] validators, uint256 amount);
    event Undelegate(address pool, string[] validators, uint256 amount);
    event NewReward(address pool, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _lsdToken,
        address _poolAddress,
        string[] memory _validators,
        address _owner,
        address _factoryAddress
    ) external initializer {
        _transferOwnership(_owner);

        _initManagerParams(_lsdToken, _poolAddress, _factoryAddress, 22, 0);

        minStakeAmount = TWELVE_DECIMALS;

        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

        for (uint256 i = 0; i < _validators.length; ++i) {
            validatorsOf[_poolAddress].add(_validators[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getValidatorsOf(address _poolAddress) public view returns (string[] memory validators) {
        return validatorsOf[_poolAddress].values();
    }

    // ------------ settings ------------

    function rmStakePool(address _poolAddress) external onlyOwner {
        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];
        if (!(poolInfo.active == 0 && poolInfo.bond == 0 && poolInfo.unbond == 0)) revert PoolNotEmpty();

        string[] memory validators = getValidatorsOf(_poolAddress);
        for (uint256 j = 0; j < validators.length; ++j) {
            if (ISeiStakePool(_poolAddress).getDelegated(validators[j]) != 0) revert DelegateNotEmpty();

            validatorsOf[_poolAddress].remove(validators[j]);
        }

        if (!bondedPools.remove(_poolAddress)) revert PoolNotExist(_poolAddress);
    }

    function addValidator(address _poolAddress, string calldata _validator) external onlyOwner {
        if (validatorsOf[_poolAddress].length() >= MAX_VALIDATORS_LEN) revert ValidatorsLenExceedLimit();
        if (!validatorsOf[_poolAddress].add(_validator)) revert ValidatorDuplicated();
    }

    function rmValidator(address _poolAddress, string calldata _validator) external onlyOwner {
        if (ISeiStakePool(_poolAddress).getDelegated(_validator) != 0) revert DelegateNotEmpty();
        if (!validatorsOf[_poolAddress].remove(_validator)) revert ValidatorNotExist();
    }

    function toggleUnstakeSwitch() external onlyOwner {
        unstakeSwitch = !unstakeSwitch;
    }

    // ------ delegation balancer

    function redelegate(
        address _poolAddress,
        string memory _srcValidator,
        string memory _dstValidator,
        uint256 _amount
    ) external onlyDelegationBalancer {
        if (!validatorsOf[_poolAddress].contains(_srcValidator)) revert ValidatorNotExist();
        if (keccak256(bytes(_srcValidator)) == keccak256(bytes(_dstValidator))) revert ValidatorDuplicated();
        if (_amount == 0) revert ZeroRedelegateAmount();
        if (!validatorsOf[_poolAddress].contains(_dstValidator)) {
            validatorsOf[_poolAddress].add(_dstValidator);
        }
        ISeiStakePool(_poolAddress).redelegate(_srcValidator, _dstValidator, _amount);
        if (ISeiStakePool(_poolAddress).getDelegated(_srcValidator) == 0) {
            validatorsOf[_poolAddress].remove(_srcValidator);
        }
    }

    // ----- staker operation

    function stake() external payable {
        stakeWithPool(bondedPools.at(0));
    }

    function unstake(uint256 _lsdTokenAmount) external {
        unstakeWithPool(bondedPools.at(0), _lsdTokenAmount);
    }

    function withdraw() external {
        withdrawWithPool(bondedPools.at(0));
    }

    function stakeWithPool(address _poolAddress) public payable {
        // Sei is an Cosmos SDK based chain, it only takes 6 decimals account in staking method,
        // here we do the same for coherence and accuracy.
        uint256 stakeAmount = (msg.value / TWELVE_DECIMALS) * TWELVE_DECIMALS;

        if (stakeAmount < minStakeAmount) revert NotEnoughStakeAmount();
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);

        uint256 lsdTokenAmount = (stakeAmount * EIGHTEEN_DECIMALS) / rate;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.bond = poolInfo.bond + stakeAmount;
        poolInfo.active = poolInfo.active + stakeAmount;

        (bool result, ) = _poolAddress.call{value: stakeAmount}("");
        if (!result) revert FailedToCall();

        // mint lsdToken
        ILsdToken(lsdToken).mint(msg.sender, lsdTokenAmount);

        emit Stake(msg.sender, _poolAddress, stakeAmount, lsdTokenAmount);
    }

    function unstakeWithPool(address _poolAddress, uint256 _lsdTokenAmount) public {
        if (!unstakeSwitch) revert UnstakeNotOpen();
        if (_lsdTokenAmount == 0) revert ZeroUnstakeAmount();
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);
        if (unstakesOfUser[msg.sender].length() >= UNSTAKE_TIMES_LIMIT) revert UnstakeTimesExceedLimit();

        uint256 tokenAmount = (_lsdTokenAmount * rate) / EIGHTEEN_DECIMALS;
        tokenAmount = (tokenAmount / TWELVE_DECIMALS) * TWELVE_DECIMALS;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.unbond += tokenAmount;
        poolInfo.active -= tokenAmount;

        // burn lsdToken
        ERC20Burnable(lsdToken).burnFrom(msg.sender, _lsdTokenAmount);

        // unstake info
        uint256 willUseUnstakeIndex = nextUnstakeIndex;
        nextUnstakeIndex = willUseUnstakeIndex + 1;

        unstakeAtIndex[willUseUnstakeIndex] = UnstakeInfo({
            era: currentEra(),
            pool: _poolAddress,
            receiver: msg.sender,
            amount: tokenAmount
        });
        unstakesOfUser[msg.sender].add(willUseUnstakeIndex);

        emit Unstake(msg.sender, _poolAddress, tokenAmount, _lsdTokenAmount, willUseUnstakeIndex);
    }

    function withdrawWithPool(address _poolAddress) public {
        uint256 totalWithdrawAmount;
        uint256[] memory unstakeIndexList = getUnstakeIndexListOf(msg.sender);
        uint256 length = unstakesOfUser[msg.sender].length();
        int256[] memory emitUnstakeIndexList = new int256[](length);

        uint256 curEra = currentEra();
        for (uint256 i = 0; i < length; ++i) {
            uint256 unstakeIndex = unstakeIndexList[i];
            UnstakeInfo memory unstakeInfo = unstakeAtIndex[unstakeIndex];
            if (unstakeInfo.era + unbondingDuration > curEra || unstakeInfo.pool != _poolAddress) {
                emitUnstakeIndexList[i] = -1;
                continue;
            }

            if (!unstakesOfUser[msg.sender].remove(unstakeIndex)) revert AlreadyWithdrawed();

            totalWithdrawAmount = totalWithdrawAmount + unstakeInfo.amount;
            emitUnstakeIndexList[i] = int256(unstakeIndex);
        }

        if (totalWithdrawAmount <= 0) revert ZeroWithdrawAmount();
        ISeiStakePool(_poolAddress).withdrawForStaker(msg.sender, totalWithdrawAmount);

        emit Withdraw(msg.sender, _poolAddress, totalWithdrawAmount, emitUnstakeIndexList);
    }

    // ----- permissionless

    function newEra() external {
        uint256 _era = latestEra + 1;
        if (currentEra() < _era) revert EraNotMatch();

        // update era
        latestEra = _era;

        uint256 totalNewReward;
        uint256 newTotalActive;
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];

            string[] memory validators = getValidatorsOf(poolAddress);

            // withdraw reward
            uint256 poolNewReward = ISeiStakePool(poolAddress).withdrawDelegationRewardsMulti(validators);
            emit NewReward(poolAddress, poolNewReward);
            totalNewReward = totalNewReward + poolNewReward;

            // bond or unbond
            PoolInfo memory poolInfo = poolInfoOf[poolAddress];
            uint256 poolBondAndNewReward = poolInfo.bond + poolNewReward;
            if (poolBondAndNewReward > poolInfo.unbond) {
                uint256 needDelegate = poolBondAndNewReward - poolInfo.unbond;
                ISeiStakePool(poolAddress).delegateMulti(validators, needDelegate);

                emit Delegate(poolAddress, validators, needDelegate);
            } else if (poolBondAndNewReward < poolInfo.unbond) {
                uint256 needUndelegate = poolInfo.unbond - poolBondAndNewReward;
                ISeiStakePool(poolAddress).undelegateMulti(validators, needUndelegate);

                emit Undelegate(poolAddress, validators, needUndelegate);
            }

            // cal total active
            uint256 newPoolActive = ISeiStakePool(poolAddress).getTotalDelegated(validators);
            newTotalActive = newTotalActive + newPoolActive;

            // update pool state
            poolInfo.era = latestEra;
            poolInfo.active = newPoolActive;
            poolInfo.bond = 0;
            poolInfo.unbond = 0;

            poolInfoOf[poolAddress] = poolInfo;
        }

        // ditribute protocol fee
        _distributeReward(totalNewReward, rate);

        // update rate
        uint256 newRate = _calRate(newTotalActive, ERC20(lsdToken).totalSupply());
        _setEraRate(_era, newRate);

        emit ExecuteNewEra(_era, newRate);
    }
}
