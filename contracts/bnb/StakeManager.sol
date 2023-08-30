pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/IBnbStakePool.sol";
import "../interfaces/ILsdToken.sol";
import "./Multisig.sol";
import "../base/Manager.sol";

contract StakeManager is Multisig, Manager {
    // Custom errors to provide more descriptive revert messages.
    error PoolNotEmpty();
    error DelegateNotEmpty();
    error PendingDelegateNotEmpty();
    error PoolNotExist(address poolAddress);
    error FailedToWithdrawRelayerFee();
    error ValidatorNotExist();
    error ValidatorDuplicated();
    error ZeroRedelegateAmount();
    error PendingRedelegationExist();
    error NotEnoughStakeValue();
    error NotEnoughStakeAmount();
    error FailedToTransferBnb();
    error ZeroUnstakeAmount();
    error NotEnoughFee();
    error UnstakeTimesExceedLimit();
    error AlreadyWithdrawed();
    error RequestInFly();
    error EraNotMatch();
    error ListLengthNotMatch();
    error RewardTimestampNotMatch();
    error PoolDuplicated(address poolAddress);

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant CROSS_DISTRIBUTE_RELAY_FEE = 6 * 1e15;

    uint256 public delegatedDiffLimit;

    mapping(address => EnumerableSet.AddressSet) validatorsOf;
    mapping(address => uint256) public latestRewardTimestampOf;
    mapping(address => uint256) public undistributedRewardOf;
    mapping(address => uint256) public pendingDelegateOf;
    mapping(address => uint256) public pendingUndelegateOf;
    // delegator => validator => amount
    mapping(address => mapping(address => uint256)) public delegatedOfValidator;
    mapping(address => bool) public waitingRemovedValidator;

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
    event Settle(uint256 indexed era, address indexed pool);
    event RepairDelegated(address pool, address validator, uint256 govDelegated, uint256 localDelegated);
    event Delegate(address pool, address validator, uint256 amount);
    event Undelegate(address pool, address validator, uint256 amount);

    function init(
        address[] calldata _initialVoters,
        uint256 _initialThreshold,
        address _lsdToken,
        address _poolAddress,
        address _validator
    ) external {
        if (_validator == address(0)) revert NotValidAddress();

        initMultisig(_initialVoters, _initialThreshold);
        _initManagerParams(_lsdToken, _poolAddress, 16, 3 * 1e14);

        validatorsOf[_poolAddress].add(_validator);

        delegatedDiffLimit = 1e11;
    }

    function getStakeRelayerFee() public view returns (uint256) {
        return IBnbStakePool(bondedPools.at(0)).getRelayerFee() / 2;
    }

    function getUnstakeRelayerFee() public view returns (uint256) {
        return IBnbStakePool(bondedPools.at(0)).getRelayerFee();
    }

    function getValidatorsOf(address _poolAddress) public view returns (address[] memory validators) {
        validators = new address[](validatorsOf[_poolAddress].length());
        for (uint256 i = 0; i < validatorsOf[_poolAddress].length(); ++i) {
            validators[i] = validatorsOf[_poolAddress].at(i);
        }
        return validators;
    }

    function setDelegatedDiffLimit(uint256 _delegatedDiffLimit) external onlyOwner {
        delegatedDiffLimit = _delegatedDiffLimit;
    }

    function rmStakePool(address _poolAddress) external onlyOwner {
        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];
        if (!(poolInfo.active == 0 && poolInfo.bond == 0 && poolInfo.unbond == 0)) revert PoolNotEmpty();
        if (IBnbStakePool(_poolAddress).getTotalDelegated() != 0) revert DelegateNotEmpty();
        if (!(pendingDelegateOf[_poolAddress] == 0 &&
                pendingUndelegateOf[_poolAddress] == 0 &&
                undistributedRewardOf[_poolAddress] == 0)) revert PendingDelegateNotEmpty();
        if (!bondedPools.remove(_poolAddress)) revert PoolNotExist(_poolAddress);
    }

    function rmValidator(address _poolAddress, address _validator) external onlyOwner {
        if (IBnbStakePool(_poolAddress).getDelegated(_validator) != 0) revert DelegateNotEmpty();

        validatorsOf[_poolAddress].remove(_validator);
        delegatedOfValidator[_poolAddress][_validator] = 0;
        delete (waitingRemovedValidator[_validator]);
    }

    function withdrawRelayerFee(address _to) external onlyOwner {
        (bool success, ) = _to.call{value: address(this).balance}("");
        if (!success) revert FailedToWithdrawRelayerFee();
    }

    // ------ delegation balancer

    function redelegate(
        address _poolAddress,
        address _srcValidator,
        address _dstValidator,
        uint256 _amount
    ) external onlyDelegationBalancer {
        if (!validatorsOf[_poolAddress].contains(_srcValidator)) revert ValidatorNotExist();
        if (_srcValidator == _dstValidator) revert ValidatorDuplicated();
        if (_amount == 0) revert ZeroRedelegateAmount();

        if (!validatorsOf[_poolAddress].contains(_dstValidator)) {
            validatorsOf[_poolAddress].add(_dstValidator);
        }

        if (!(block.timestamp >= IBnbStakePool(_poolAddress).getPendingRedelegateTime(_srcValidator, _dstValidator) &&
                block.timestamp >= IBnbStakePool(_poolAddress).getPendingRedelegateTime(_dstValidator, _srcValidator)))
            revert PendingRedelegationExist();

        _checkAndRepairDelegated(_poolAddress);

        delegatedOfValidator[_poolAddress][_srcValidator] = delegatedOfValidator[_poolAddress][_srcValidator] - _amount;
        delegatedOfValidator[_poolAddress][_dstValidator] = delegatedOfValidator[_poolAddress][_dstValidator] + _amount;

        IBnbStakePool(_poolAddress).redelegate(_srcValidator, _dstValidator, _amount);

        if (delegatedOfValidator[_poolAddress][_srcValidator] == 0) {
            waitingRemovedValidator[_srcValidator] = true;
        }
    }

    // ----- staker operation

    function stake(uint256 _stakeAmount) external payable {
        stakeWithPool(bondedPools.at(0), _stakeAmount);
    }

    function unstake(uint256 _lsdTokenAmount) external payable {
        unstakeWithPool(bondedPools.at(0), _lsdTokenAmount);
    }

    function withdraw() external payable {
        withdrawWithPool(bondedPools.at(0));
    }

    function stakeWithPool(address _poolAddress, uint256 _stakeAmount) public payable {
        if (msg.value < _stakeAmount + getStakeRelayerFee()) revert NotEnoughStakeValue();
        if (_stakeAmount < minStakeAmount) revert NotEnoughStakeAmount();
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);

        uint256 lsdTokenAmount = (_stakeAmount * 1e18) / rate;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.bond = poolInfo.bond + _stakeAmount;
        poolInfo.active = poolInfo.active + _stakeAmount;

        // transfer token
        (bool success, ) = _poolAddress.call{value: _stakeAmount}("");
        if (!success) revert FailedToTransferBnb();

        // mint lsdToken
        ILsdToken(lsdToken).mint(msg.sender, lsdTokenAmount);

        emit Stake(msg.sender, _poolAddress, _stakeAmount, lsdTokenAmount);
    }

    function unstakeWithPool(address _poolAddress, uint256 _lsdTokenAmount) public payable {
        if (_lsdTokenAmount == 0) revert ZeroUnstakeAmount();
        if (msg.value < getUnstakeRelayerFee()) revert NotEnoughFee();
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);
        if (unstakesOfUser[msg.sender].length() >= UNSTAKE_TIMES_LIMIT) revert UnstakeTimesExceedLimit();

        uint256 tokenAmount = (_lsdTokenAmount * rate) / 1e18;

        // update pool
        PoolInfo storage poolInfo = poolInfoOf[_poolAddress];
        poolInfo.unbond = poolInfo.unbond + tokenAmount;
        poolInfo.active = poolInfo.active - tokenAmount;

        // burn lsdToken
        ERC20Burnable(lsdToken).burnFrom(msg.sender, _lsdTokenAmount);

        // unstake info
        unstakeAtIndex[nextUnstakeIndex] = UnstakeInfo({
            era: currentEra(),
            pool: _poolAddress,
            receiver: msg.sender,
            amount: tokenAmount
        });
        unstakesOfUser[msg.sender].add(nextUnstakeIndex);

        emit Unstake(msg.sender, _poolAddress, tokenAmount, _lsdTokenAmount, nextUnstakeIndex);

        nextUnstakeIndex = nextUnstakeIndex + 1;
    }

    function withdrawWithPool(address _poolAddress) public payable {
        if (msg.value < CROSS_DISTRIBUTE_RELAY_FEE) revert NotEnoughFee();

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

            if (!unstakesOfUser[msg.sender].remove(unstakeIndex)) revert AlreadyWithdrawed();

            totalWithdrawAmount = totalWithdrawAmount + unstakeInfo.amount;
            emitUnstakeIndexList[i] = int256(unstakeIndex);
        }

        if (totalWithdrawAmount > 0) {
            IBnbStakePool(_poolAddress).withdrawForStaker(msg.sender, totalWithdrawAmount);
        }

        emit Withdraw(msg.sender, _poolAddress, totalWithdrawAmount, emitUnstakeIndexList);
    }

    // ----- permissionless

    function settle(address _poolAddress) external {
        if (!bondedPools.contains(_poolAddress)) revert PoolNotExist(_poolAddress);
        _checkAndRepairDelegated(_poolAddress);

        // claim undelegated
        IBnbStakePool(_poolAddress).checkAndClaimUndelegated();

        PoolInfo memory poolInfo = poolInfoOf[_poolAddress];

        // cal pending value
        uint256 pendingDelegate = pendingDelegateOf[_poolAddress] + poolInfo.bond;
        uint256 pendingUndelegate = pendingUndelegateOf[_poolAddress] + poolInfo.unbond;

        uint256 deduction = pendingDelegate > pendingUndelegate ? pendingUndelegate : pendingDelegate;
        pendingDelegate = pendingDelegate - deduction;
        pendingUndelegate = pendingUndelegate - deduction;

        // update pool state
        poolInfo.bond = 0;
        poolInfo.unbond = 0;
        poolInfoOf[_poolAddress] = poolInfo;

        _settle(_poolAddress, pendingDelegate, pendingUndelegate);
    }

    // ----- vote

    function newEra(
        address[] calldata _poolAddressList,
        uint256[] calldata _newRewardList,
        uint256[] calldata _latestRewardTimestampList
    ) external onlyVoter {
        uint256 _era = latestEra + 1;
        bytes32 proposalId = keccak256(
            abi.encodePacked("newEra", _era, _poolAddressList, _newRewardList, _latestRewardTimestampList)
        );
        Proposal memory proposal = _checkProposal(proposalId);

        // Finalize if Threshold has been reached
        if (proposal._yesVotesTotal >= threshold) {
            _executeNewEra(_era, _poolAddressList, _newRewardList, _latestRewardTimestampList);

            proposal._status = ProposalStatus.Executed;
            emit ProposalExecuted(proposalId);
        }

        proposals[proposalId] = proposal;
    }

    // ----- helper

    function _checkAndRepairDelegated(address _poolAddress) private {
        uint256[3] memory requestInFly = IBnbStakePool(_poolAddress).getRequestInFly();
        if (!(requestInFly[0] == 0 && requestInFly[1] == 0 && requestInFly[2] == 0)) revert RequestInFly();

        uint256 valLength = validatorsOf[_poolAddress].length();
        for (uint256 i = 0; i < valLength; ++i) {
            address val = validatorsOf[_poolAddress].at(i);
            uint256 govDelegated = IBnbStakePool(_poolAddress).getDelegated(val);
            uint256 localDelegated = delegatedOfValidator[_poolAddress][val];

            uint256 diff;
            if (govDelegated > localDelegated + delegatedDiffLimit) {
                diff = govDelegated - localDelegated;

                pendingUndelegateOf[_poolAddress] = pendingUndelegateOf[_poolAddress] + diff;
            } else if (localDelegated > govDelegated + delegatedDiffLimit) {
                diff = localDelegated - govDelegated;

                pendingDelegateOf[_poolAddress] = pendingDelegateOf[_poolAddress] + diff;
            }

            delegatedOfValidator[_poolAddress][val] = govDelegated;
            emit RepairDelegated(_poolAddress, val, govDelegated, localDelegated);
        }
    }

    function _executeNewEra(
        uint256 _era,
        address[] calldata _poolAddressList,
        uint256[] calldata _newRewardList,
        uint256[] calldata _latestRewardTimestampList
    ) private {
        if (currentEra() < _era) revert EraNotMatch();
        if (!(_poolAddressList.length == bondedPools.length() &&
                _poolAddressList.length == _newRewardList.length &&
                _poolAddressList.length == _latestRewardTimestampList.length)) revert ListLengthNotMatch();
        // update era
        latestEra = _era;
        // update pool info
        uint256 totalNewReward;
        uint256 totalNewActive;
        for (uint256 i = 0; i < _poolAddressList.length; ++i) {
            address poolAddress = _poolAddressList[i];
            if (!(_latestRewardTimestampList[i] >= latestRewardTimestampOf[poolAddress] &&
                    _latestRewardTimestampList[i] < block.timestamp)) revert RewardTimestampNotMatch();

            PoolInfo memory poolInfo = poolInfoOf[poolAddress];
            if (poolInfo.era == latestEra) revert PoolDuplicated(poolAddress);
            if (!bondedPools.contains(poolAddress)) revert PoolNotExist(poolAddress);

            _checkAndRepairDelegated(poolAddress);

            // update latest reward timestamp
            latestRewardTimestampOf[poolAddress] = _latestRewardTimestampList[i];

            if (_newRewardList[i] > 0) {
                // update undistributedReward
                undistributedRewardOf[poolAddress] = undistributedRewardOf[poolAddress] + _newRewardList[i];
                // total new reward
                totalNewReward = totalNewReward + _newRewardList[i];
            }

            // claim distributed reward
            if (currentEra() == _era) {
                uint256 claimedReward = IBnbStakePool(poolAddress).checkAndClaimReward();
                if (claimedReward > 0) {
                    claimedReward = claimedReward + CROSS_DISTRIBUTE_RELAY_FEE;
                    if (undistributedRewardOf[poolAddress] > claimedReward) {
                        undistributedRewardOf[poolAddress] = undistributedRewardOf[poolAddress] - claimedReward;
                    } else {
                        undistributedRewardOf[poolAddress] = 0;
                    }
                    pendingDelegateOf[poolAddress] = pendingDelegateOf[poolAddress] + claimedReward;
                }
            }

            // claim undelegated
            IBnbStakePool(poolAddress).checkAndClaimUndelegated();

            // update pending value
            uint256 pendingDelegate = pendingDelegateOf[poolAddress] + poolInfo.bond;
            uint256 pendingUndelegate = pendingUndelegateOf[poolAddress] + poolInfo.unbond;

            uint256 deduction = pendingDelegate > pendingUndelegate ? pendingUndelegate : pendingDelegate;
            pendingDelegate = pendingDelegate - deduction;
            pendingUndelegate = pendingUndelegate - deduction;

            // cal total active
            uint256 poolNewActive = IBnbStakePool(poolAddress)
                .getTotalDelegated()
                + pendingDelegate
                + undistributedRewardOf[poolAddress]
                - pendingUndelegate;

            totalNewActive = totalNewActive + poolNewActive;

            // update pool state
            poolInfo.era = latestEra;
            poolInfo.active = poolNewActive;
            poolInfo.bond = 0;
            poolInfo.unbond = 0;

            poolInfoOf[poolAddress] = poolInfo;

            // settle
            _settle(poolAddress, pendingDelegate, pendingUndelegate);
        }

        // cal protocol fee
        if (totalNewReward > 0) {
            uint256 lsdTokenProtocolFee = (totalNewReward * protocolFeeCommission) / rate;

            if (lsdTokenProtocolFee > 0) {
                totalProtocolFee = totalProtocolFee + lsdTokenProtocolFee;
                // mint lsdToken
                ILsdToken(lsdToken).mint(address(this), lsdTokenProtocolFee);
            }
        }

        // update rate
        uint256 newRate = (totalNewActive * 1e18) / (ERC20Burnable(lsdToken).totalSupply());
        _setEraRate(_era, newRate);

        emit ExecuteNewEra(_era, newRate);
    }

    // maybe call delegate/undelegate to stakepool and update pending value
    function _settle(address _poolAddress, uint256 pendingDelegate, uint256 pendingUndelegate) private {
        // delegate and cal pending value
        uint256 minDelegation = IBnbStakePool(_poolAddress).getMinDelegation();
        if (pendingDelegate >= minDelegation) {
            for (uint256 i = 0; i < validatorsOf[_poolAddress].length(); ++i) {
                address val = validatorsOf[_poolAddress].at(i);
                if (waitingRemovedValidator[val]) {
                    continue;
                }
                delegatedOfValidator[_poolAddress][val] = delegatedOfValidator[_poolAddress][val] + pendingDelegate;
                IBnbStakePool(_poolAddress).delegate(val, pendingDelegate);

                emit Delegate(_poolAddress, val, pendingDelegate);

                pendingDelegate = 0;
                break;
            }
        }

        // undelegate and cal pending value
        if (pendingUndelegate > 0) {
            uint256 needUndelegate = pendingUndelegate;
            uint256 realUndelegate = 0;
            uint256 relayerFee = IBnbStakePool(_poolAddress).getRelayerFee();

            for (uint256 i = 0; i < validatorsOf[_poolAddress].length(); ++i) {
                if (needUndelegate == 0) {
                    break;
                }
                address val = validatorsOf[_poolAddress].at(i);

                if (block.timestamp < IBnbStakePool(_poolAddress).getPendingUndelegateTime(val)) {
                    continue;
                }

                uint256 govDelegated = IBnbStakePool(_poolAddress).getDelegated(val);
                if (needUndelegate < govDelegated) {
                    uint256 willUndelegate = needUndelegate;
                    if (willUndelegate < minDelegation) {
                        willUndelegate = minDelegation;
                        if (willUndelegate > govDelegated) {
                            willUndelegate = govDelegated;
                        }
                    }

                    if (willUndelegate < govDelegated && govDelegated - willUndelegate < relayerFee) {
                        willUndelegate = govDelegated;
                    }

                    delegatedOfValidator[_poolAddress][val] = delegatedOfValidator[_poolAddress][val] - willUndelegate;
                    IBnbStakePool(_poolAddress).undelegate(val, willUndelegate);

                    emit Undelegate(_poolAddress, val, willUndelegate);

                    needUndelegate = 0;
                    realUndelegate = realUndelegate + willUndelegate;
                } else {
                    delegatedOfValidator[_poolAddress][val] = delegatedOfValidator[_poolAddress][val] - govDelegated;
                    IBnbStakePool(_poolAddress).undelegate(val, govDelegated);

                    emit Undelegate(_poolAddress, val, govDelegated);

                    needUndelegate = needUndelegate - govDelegated;
                    realUndelegate = realUndelegate + govDelegated;
                }
            }

            if (realUndelegate > pendingUndelegate) {
                pendingDelegate = pendingDelegate + realUndelegate - pendingUndelegate;
                pendingUndelegate = 0;
            } else {
                pendingUndelegate = pendingUndelegate - realUndelegate;
            }
        }

        // update pending value
        pendingDelegateOf[_poolAddress] = pendingDelegate;
        pendingUndelegateOf[_poolAddress] = pendingUndelegate;

        emit Settle(currentEra(), _poolAddress);
    }
}
