pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "./interfaces/IStaking.sol";
import "./interfaces/IBnbStakePool.sol";

contract StakePool is IBnbStakePool {
    uint256 public constant TEN_DECIMALS = 1e10;

    address public stakingAddress;
    address public stakeManagerAddress;

    modifier onlyStakeManager() {
        require(msg.sender == stakeManagerAddress, "StakePool: only stakeManager");
        _;
    }

    receive() external payable {}

    function init(address _stakingAddress, address _stakeManagerAddress) external {
        require(stakingAddress == address(0), "StakePool: already init");
        require(_stakeManagerAddress != address(0), "StakePool: zero stake manager address");

        stakingAddress = _stakingAddress;
        stakeManagerAddress = _stakeManagerAddress;
    }

    function checkAndClaimReward() external override onlyStakeManager returns (uint256) {
        if (IStaking(stakingAddress).getDistributedReward(address(this)) > 0) {
            return IStaking(stakingAddress).claimReward();
        }
        return 0;
    }

    function checkAndClaimUndelegated() external override onlyStakeManager returns (uint256) {
        if (IStaking(stakingAddress).getUndelegated(address(this)) > 0) {
            return IStaking(stakingAddress).claimUndelegated();
        }
        return 0;
    }

    function delegate(address validator, uint256 amount) external override onlyStakeManager {
        amount = (amount / TEN_DECIMALS) * TEN_DECIMALS;
        uint256 relayerFee = IStaking(stakingAddress).getRelayerFee();
        IStaking(stakingAddress).delegate{value: amount + relayerFee}(validator, amount);
    }

    function undelegate(address validator, uint256 amount) external override onlyStakeManager {
        amount = (amount / TEN_DECIMALS) * TEN_DECIMALS;
        uint256 relayerFee = IStaking(stakingAddress).getRelayerFee();
        IStaking(stakingAddress).undelegate{value: relayerFee}(validator, amount);
    }

    function redelegate(address validatorSrc, address validatorDst, uint256 amount) external override onlyStakeManager {
        amount = (amount / TEN_DECIMALS) * TEN_DECIMALS;
        uint256 relayerFee = IStaking(stakingAddress).getRelayerFee();
        IStaking(stakingAddress).redelegate{value: relayerFee}(validatorSrc, validatorDst, amount);
    }

    function withdrawForStaker(address staker, uint256 amount) external override onlyStakeManager {
        if (amount > 0) {
            (bool result, ) = staker.call{value: amount}("");
            require(result, "StakePool: withdraw call failed");
        }
    }

    function getTotalDelegated() external view override returns (uint256) {
        return IStaking(stakingAddress).getTotalDelegated(address(this));
    }

    function getDelegated(address validator) external view override returns (uint256) {
        return IStaking(stakingAddress).getDelegated(address(this), validator);
    }

    function getMinDelegation() external view override returns (uint256) {
        return IStaking(stakingAddress).getMinDelegation();
    }

    function getPendingUndelegateTime(address validator) external view override returns (uint256) {
        return IStaking(stakingAddress).getPendingUndelegateTime(address(this), validator);
    }

    function getRequestInFly() external view override returns (uint256[3] memory) {
        return IStaking(stakingAddress).getRequestInFly(address(this));
    }

    function getRelayerFee() external view override returns (uint256) {
        return IStaking(stakingAddress).getRelayerFee();
    }

    function getPendingRedelegateTime(address valSrc, address valDst) external view override returns (uint256) {
        return IStaking(stakingAddress).getPendingRedelegateTime(address(this), valSrc, valDst);
    }
}
