pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IMaticStakePool.sol";
import "../interfaces/IERC20MintBurn.sol";
import "../base/Manager.sol";

contract StakeManager is Manager {
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
        address staker,
        address poolAddress,
        uint256 tokenAmount,
        uint256 lsdTokenAmount,
        uint256 unstakeIndex
    );
    event Withdraw(address staker, address poolAddress, uint256 tokenAmount, int256[] unstakeIndexList);
    event ExecuteNewEra(uint256 indexed era, uint256 rate);
    event Delegate(address pool, uint256 validator, uint256 amount);
    event Undelegate(address pool, uint256 validator, uint256 amount);
    event NewReward(address pool, uint256 amount);
    event NewClaimedNonce(address pool, uint256 validator, uint256 nonce);

    // init
    function init(address _lsdToken, address _stakeTokenAddress, address _poolAddress, uint256 _validatorId) public {
        require(_stakeTokenAddress != address(0), "StakeManager: zero token address");

        _initManagerParams(_lsdToken, _poolAddress, 4, 5 * 1e14);

        validatorIdsOf[_poolAddress].add(_validatorId);
        stakeTokenAddress = _stakeTokenAddress;

        _transferOwnership(msg.sender);

        IMaticStakePool(_poolAddress).approveForStakeManager(stakeTokenAddress, 1e28);
    }

    function getValidatorIdsOf(address _poolAddress) public view returns (uint256[] memory validatorIds) {
        validatorIds = new uint256[](validatorIdsOf[_poolAddress].length());
        for (uint256 i = 0; i < validatorIdsOf[_poolAddress].length(); ++i) {
            validatorIds[i] = validatorIdsOf[_poolAddress].at(i);
        }
        return validatorIds;
    }

    function rmStakePool(address _poolAddress) external onlyOwner {
        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];
        require(poolInfo.active == 0 && poolInfo.bond == 0 && poolInfo.unbond == 0, "StakeManager: pool not empty");

        uint256[] memory validators = getValidatorIdsOf(_poolAddress);
        for (uint256 j = 0; j < validators.length; ++j) {
            require(IMaticStakePool(_poolAddress).getDelegated(validators[j]) == 0, "StakeManager: delegate not empty");

            validatorIdsOf[_poolAddress].remove(validators[j]);
        }

        require(bondedPools.remove(_poolAddress), "StakeManager: pool not exist");
    }

    function approve(address _poolAddress, uint256 _amount) external onlyOwner {
        IMaticStakePool(_poolAddress).approveForStakeManager(stakeTokenAddress, _amount);
    }

    // ------ delegation balancer

    function redelegate(
        address _poolAddress,
        uint256 _srcValidatorId,
        uint256 _dstValidatorId,
        uint256 _amount
    ) external onlyDelegationBalancer {
        require(validatorIdsOf[_poolAddress].contains(_srcValidatorId), "StakeManager: val not exist");
        require(_srcValidatorId != _dstValidatorId, "StakeManager: val duplicate");
        require(_amount > 0, "StakeManager: amount zero");

        if (!validatorIdsOf[_poolAddress].contains(_dstValidatorId)) {
            validatorIdsOf[_poolAddress].add(_dstValidatorId);
        }

        IMaticStakePool(_poolAddress).redelegate(_srcValidatorId, _dstValidatorId, _amount);

        if (IMaticStakePool(_poolAddress).getDelegated(_srcValidatorId) == 0) {
            validatorIdsOf[_poolAddress].remove(_srcValidatorId);
        }
    }

    // ----- staker operation

    function stake(uint256 _stakeAmount) external {
        stakeWithPool(bondedPools.at(0), _stakeAmount);
    }

    function unstake(uint256 _lsdTokenAmount) external {
        unstakeWithPool(bondedPools.at(0), _lsdTokenAmount);
    }

    function withdraw() external {
        withdrawWithPool(bondedPools.at(0));
    }

    function stakeWithPool(address _poolAddress, uint256 _stakeAmount) public {
        require(_stakeAmount >= minStakeAmount, "StakeManager: amount not enough");
        require(bondedPools.contains(_poolAddress), "StakeManager: pool not exist");

        uint256 lsdTokenAmount = (_stakeAmount * 1e18) / rate;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.bond = poolInfo.bond + _stakeAmount;
        poolInfo.active = poolInfo.active + _stakeAmount;

        // transfer erc20 token
        IERC20(stakeTokenAddress).safeTransferFrom(msg.sender, _poolAddress, _stakeAmount);

        // mint rtoken
        IERC20MintBurn(lsdToken).mint(msg.sender, lsdTokenAmount);

        emit Stake(msg.sender, _poolAddress, _stakeAmount, lsdTokenAmount);
    }

    function unstakeWithPool(address _poolAddress, uint256 _lsdTokenAmount) public {
        require(_lsdTokenAmount > 0, "StakeManager: rtoken amount zero");
        require(bondedPools.contains(_poolAddress), "StakeManager: pool not exist");
        require(unstakesOfUser[msg.sender].length() <= UNSTAKE_TIMES_LIMIT, "StakeManager: unstake times limit");

        uint256 tokenAmount = (_lsdTokenAmount * rate) / 1e18;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.unbond = poolInfo.unbond + tokenAmount;
        poolInfo.active = poolInfo.active - tokenAmount;

        // burn rtoken
        IERC20MintBurn(lsdToken).burnFrom(msg.sender, _lsdTokenAmount);

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
        uint256 length = unstakesOfUser[msg.sender].length();
        uint256[] memory unstakeIndexList = new uint256[](length);
        int256[] memory emitUnstakeIndexList = new int256[](length);

        for (uint256 i = 0; i < length; ++i) {
            unstakeIndexList[i] = unstakesOfUser[msg.sender].at(i);
        }
        uint256 curEra = currentEra();
        for (uint256 i = 0; i < length; ++i) {
            uint256 unstakeIndex = unstakeIndexList[i];
            UnstakeInfo memory unstakeInfo = unstakeAtIndex[unstakeIndex];
            if (unstakeInfo.era + unbondingDuration > curEra || unstakeInfo.pool != _poolAddress) {
                emitUnstakeIndexList[i] = -1;
                continue;
            }

            require(unstakesOfUser[msg.sender].remove(unstakeIndex), "StakeManager: already withdrawed");

            totalWithdrawAmount = totalWithdrawAmount + unstakeInfo.amount;
            emitUnstakeIndexList[i] = int256(unstakeIndex);
        }

        if (totalWithdrawAmount > 0) {
            IMaticStakePool(_poolAddress).withdrawForStaker(stakeTokenAddress, msg.sender, totalWithdrawAmount);
        }

        emit Withdraw(msg.sender, _poolAddress, totalWithdrawAmount, emitUnstakeIndexList);
    }

    // ----- permissionless

    function newEra() external {
        uint256 _era = latestEra + 1;
        require(currentEra() >= _era, "StakeManager: calEra not match");

        // update era
        latestEra = _era;

        uint256 totalNewReward;
        uint256 newTotalActive;
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];

            uint256[] memory validators = getValidatorIdsOf(poolAddress);

            // newReward
            uint256 poolNewReward = IMaticStakePool(poolAddress).checkAndWithdrawRewards(validators);
            emit NewReward(poolAddress, poolNewReward);
            totalNewReward = totalNewReward + poolNewReward;

            // unstakeClaimTokens
            for (uint256 j = 0; j < validators.length; ++j) {
                uint256 oldClaimedNonce = maxClaimedNonceOf[poolAddress][validators[j]];
                uint256 newClaimedNonce = IMaticStakePool(poolAddress).unstakeClaimTokens(validators[j], oldClaimedNonce);
                if (newClaimedNonce > oldClaimedNonce) {
                    maxClaimedNonceOf[poolAddress][validators[j]] = newClaimedNonce;

                    emit NewClaimedNonce(poolAddress, validators[j], newClaimedNonce);
                }
            }

            // bond or unbond
            PoolInfo memory poolInfo = poolInfoOf[poolAddress];
            uint256 poolBondAndNewReward = poolInfo.bond + poolNewReward;
            if (poolBondAndNewReward > poolInfo.unbond) {
                uint256 needDelegate = poolBondAndNewReward - poolInfo.unbond;
                IMaticStakePool(poolAddress).delegate(validators[0], needDelegate);

                emit Delegate(poolAddress, validators[0], needDelegate);
            } else if (poolBondAndNewReward < poolInfo.unbond) {
                uint256 needUndelegate = poolInfo.unbond - poolBondAndNewReward;

                for (uint256 j = 0; j < validators.length; ++j) {
                    if (needUndelegate == 0) {
                        break;
                    }
                    uint256 totalStaked = IMaticStakePool(poolAddress).getDelegated(validators[j]);

                    uint256 unbondAmount;
                    if (needUndelegate < totalStaked) {
                        unbondAmount = needUndelegate;
                        needUndelegate = 0;
                    } else {
                        unbondAmount = totalStaked;
                        needUndelegate = needUndelegate - totalStaked;
                    }

                    if (unbondAmount > 0) {
                        IMaticStakePool(poolAddress).undelegate(validators[j], unbondAmount);

                        emit Undelegate(poolAddress, validators[j], unbondAmount);
                    }
                }
                require(needUndelegate == 0, "StakeManager: undelegate not enough");
            }

            // cal total active
            uint256 newPoolActive = IMaticStakePool(poolAddress).getTotalDelegated(validators);
            newTotalActive = newTotalActive + newPoolActive;

            // update pool state
            poolInfo.active = newPoolActive;
            poolInfo.bond = 0;
            poolInfo.unbond = 0;

            poolInfoOf[poolAddress] = poolInfo;
        }

        // cal protocol fee
        if (totalNewReward > 0) {
            uint256 rTokenProtocolFee = (totalNewReward * protocolFeeCommission) / rate;
            if (rTokenProtocolFee > 0) {
                totalProtocolFee = totalProtocolFee + rTokenProtocolFee;
                // mint rtoken
                IERC20MintBurn(lsdToken).mint(address(this), rTokenProtocolFee);
            }
        }

        // update rate
        uint256 newRate = (newTotalActive * 1e18) / (IERC20(lsdToken).totalSupply());
        uint256 rateChange = newRate > rate ? newRate - rate : rate - newRate;
        require((rateChange * 1e18) / rate < rateChangeLimit, "StakeManager: rate change over limit");

        rate = newRate;
        eraRate[_era] = newRate;

        emit ExecuteNewEra(_era, newRate);
    }
}
