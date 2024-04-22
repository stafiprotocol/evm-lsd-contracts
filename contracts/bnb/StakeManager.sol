// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBnbStakePool.sol";
import "../interfaces/ILsdToken.sol";
import "./interfaces/IOldStakeManager.sol";
import "../base/Manager.sol";

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
    error ValidatorInvalid();
    error StakeSwitchClosed();
    error AlreadyMigrated();
    error PoolZeroBalance();

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => EnumerableSet.AddressSet) validatorsOf;

    bool public stakeSwitch;
    uint256 public totalRTokenSupply;

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
    event Delegate(address pool, address[] validators, uint256 amount);
    event Undelegate(address pool, address[] validators, uint256 amount);
    event NewReward(address pool, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _lsdToken,
        address _poolAddress,
        address[] calldata _validators,
        address _owner,
        address _factoryAddress
    ) external initializer {
        _transferOwnership(_owner);

        _initManagerParams(_lsdToken, _poolAddress, _factoryAddress, 8, 0);

        minStakeAmount = 1e12;

        if (_validators.length == 0) {
            revert ValidatorsEmpty();
        }

        for (uint256 i = 0; i < _validators.length; ++i) {
            if (IBnbStakePool(_poolAddress).isInvalidValidator(_validators[i])) revert ValidatorInvalid();
            validatorsOf[_poolAddress].add(_validators[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getValidatorsOf(address _poolAddress) public view returns (address[] memory validators) {
        return validatorsOf[_poolAddress].values();
    }

    // ------------ settings ------------

    function rmStakePool(address _poolAddress) external onlyOwner {
        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];
        if (!(poolInfo.active == 0 && poolInfo.bond == 0 && poolInfo.unbond == 0)) revert PoolNotEmpty();

        address[] memory validators = getValidatorsOf(_poolAddress);
        for (uint256 j = 0; j < validators.length; ++j) {
            if (IBnbStakePool(_poolAddress).getDelegated(validators[j]) != 0) revert DelegateNotEmpty();

            validatorsOf[_poolAddress].remove(validators[j]);
        }

        if (!bondedPools.remove(_poolAddress)) revert PoolNotExist(_poolAddress);
    }

    function addValidator(address _poolAddress, address _validator) external onlyOwner {
        if (validatorsOf[_poolAddress].length() >= MAX_VALIDATORS_LEN) revert ValidatorsLenExceedLimit();
        if (IBnbStakePool(_poolAddress).isInvalidValidator(_validator)) revert ValidatorInvalid();
        if (!validatorsOf[_poolAddress].add(_validator)) revert ValidatorDuplicated();
    }

    function rmValidator(address _poolAddress, address _validator) external onlyOwner {
        if (IBnbStakePool(_poolAddress).getDelegated(_validator) != 0) revert DelegateNotEmpty();
        if (!validatorsOf[_poolAddress].remove(_validator)) revert ValidatorNotExist();
    }

    function stakeSwitchToggle() external onlyOwner {
        stakeSwitch = !stakeSwitch;
    }

    function migrate(address _oldStakeManager, address _oldPoolAddress, address _newPoolAddress) external onlyOwner {
        if (rate != EIGHTEEN_DECIMALS) revert AlreadyMigrated();
        if (!bondedPools.contains(_newPoolAddress)) revert PoolNotExist(_newPoolAddress);
        if (_newPoolAddress.balance == 0) revert PoolZeroBalance();

        IOldStakeManager oldStakeManager = IOldStakeManager(_oldStakeManager);
        rate = oldStakeManager.getRate();
        eraOffset = oldStakeManager.eraOffset();
        latestEra = oldStakeManager.latestEra();
        totalRTokenSupply = oldStakeManager.totalRTokenSupply();
        totalProtocolFee = oldStakeManager.totalProtocolFee();
        _setEraRate(latestEra, rate);

        // migrate active
        OldPoolInfo memory oldPoolInfo = oldStakeManager.poolInfoOf(_oldPoolAddress);
        if (oldPoolInfo.active == 0) {
            revert PoolNotExist(_oldPoolAddress);
        }
        PoolInfo storage newPoolInfo = poolInfoOf[_newPoolAddress];
        newPoolInfo.active = oldPoolInfo.active;

        // delegate
        IBnbStakePool stakePool = IBnbStakePool(_newPoolAddress);
        address[] memory validators = getValidatorsOf(_newPoolAddress);

        stakePool.delegateMulti(validators, _newPoolAddress.balance);
    }

    // ------ delegation balancer

    function redelegate(
        address _poolAddress,
        address _srcValidator,
        address _dstValidator,
        uint256 _amount
    ) external payable onlyDelegationBalancer {
        if (!validatorsOf[_poolAddress].contains(_srcValidator)) revert ValidatorNotExist();
        if (_srcValidator == _dstValidator) revert ValidatorDuplicated();
        if (_amount == 0) revert ZeroRedelegateAmount();
        if (!validatorsOf[_poolAddress].contains(_dstValidator)) {
            if (IBnbStakePool(_poolAddress).isInvalidValidator(_dstValidator)) revert ValidatorInvalid();
            validatorsOf[_poolAddress].add(_dstValidator);
        }
        IBnbStakePool(_poolAddress).redelegate{value: msg.value}(_srcValidator, _dstValidator, _amount);
        if (IBnbStakePool(_poolAddress).getDelegated(_srcValidator) == 0) {
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
        if (!stakeSwitch) revert StakeSwitchClosed();
        uint256 stakeAmount = msg.value;
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
        totalRTokenSupply += lsdTokenAmount;
        ILsdToken(lsdToken).mint(msg.sender, lsdTokenAmount);

        emit Stake(msg.sender, _poolAddress, stakeAmount, lsdTokenAmount);
    }

    function unstakeWithPool(address _poolAddress, uint256 _lsdTokenAmount) public {
        if (!stakeSwitch) revert StakeSwitchClosed();
        if (_lsdTokenAmount == 0) revert ZeroUnstakeAmount();
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);
        if (unstakesOfUser[msg.sender].length() >= UNSTAKE_TIMES_LIMIT) revert UnstakeTimesExceedLimit();

        uint256 tokenAmount = (_lsdTokenAmount * rate) / EIGHTEEN_DECIMALS;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.unbond += tokenAmount;
        poolInfo.active -= tokenAmount;

        // burn lsdToken
        totalRTokenSupply -= _lsdTokenAmount;
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
        IBnbStakePool(_poolAddress).withdrawForStaker(msg.sender, totalWithdrawAmount);

        emit Withdraw(msg.sender, _poolAddress, totalWithdrawAmount, emitUnstakeIndexList);
    }

    // ----- permissionless

    function newEra() external {
        if (!stakeSwitch) revert StakeSwitchClosed();
        uint256 _era = latestEra + 1;
        if (currentEra() < _era) revert EraNotMatch();

        // update era
        latestEra = _era;

        uint256 totalNewReward;
        uint256 newTotalActive;
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];
            IBnbStakePool stakePool = IBnbStakePool(poolAddress);
            address[] memory validators = getValidatorsOf(poolAddress);

            // claim undelegated
            stakePool.claimUndelegated(validators);

            // bond or unbond
            PoolInfo memory poolInfo = poolInfoOf[poolAddress];
            if (poolInfo.bond > poolInfo.unbond) {
                uint256 needDelegate = poolInfo.bond - poolInfo.unbond;
                stakePool.delegateMulti(validators, needDelegate);

                emit Delegate(poolAddress, validators, needDelegate);
            } else if (poolInfo.bond < poolInfo.unbond) {
                uint256 needUndelegate = poolInfo.unbond - poolInfo.bond;
                stakePool.undelegateMulti(validators, needUndelegate);

                emit Undelegate(poolAddress, validators, needUndelegate);
            }

            // cal total active
            uint256 newPoolActive = stakePool.getTotalDelegated(validators);
            newTotalActive += newPoolActive;

            // cal total reward
            uint256 poolNewReward = newPoolActive > poolInfo.active ? newPoolActive - poolInfo.active : 0;
            totalNewReward += poolNewReward;

            emit NewReward(poolAddress, poolNewReward);

            // update pool state
            poolInfo.era = latestEra;
            poolInfo.active = newPoolActive;
            poolInfo.bond = 0;
            poolInfo.unbond = 0;

            poolInfoOf[poolAddress] = poolInfo;
        }

        // ditribute protocol fee
        if (totalNewReward > 0) {
            uint256 lsdTokenProtocolFee = (totalNewReward * protocolFeeCommission) / rate;

            totalRTokenSupply += lsdTokenProtocolFee;

            uint256 factoryFee = (lsdTokenProtocolFee * factoryFeeCommission) / 1e18;
            lsdTokenProtocolFee = lsdTokenProtocolFee - factoryFee;

            if (lsdTokenProtocolFee > 0) {
                totalProtocolFee = totalProtocolFee + lsdTokenProtocolFee;
                // mint lsdToken
                ILsdToken(lsdToken).mint(address(this), lsdTokenProtocolFee);
            }

            if (factoryFee > 0) {
                ILsdToken(lsdToken).mint(factoryAddress, factoryFee);
            }
        }

        // update rate
        uint256 newRate = _calRate(newTotalActive, totalRTokenSupply);
        _setEraRate(_era, newRate);

        emit ExecuteNewEra(_era, newRate);
    }
}
