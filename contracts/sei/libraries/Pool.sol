pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only
import "../StakePool.sol";

library Pool {
    uint256 public constant DEFAULT_ERA_SECONDS = 86400;

    struct State {
        address pool;
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

    struct InitParams {
        string lsdTokenName;
        string lsdTokenSymbol;
        uint256 minimalStake;
        uint256 platformFeeCommission;
        address platformFeeReceiver;
        string[] validators;
    }

    function init(
        State storage self,
        InitParams memory params,
        address lsdToken,
        address stakePool,
        uint8 unbondingPeriod
    ) internal {
        int256 offset = 0 - int256(block.timestamp / DEFAULT_ERA_SECONDS);

        self.pool = stakePool;
        self.admin = msg.sender;
        self.lsdToken = lsdToken;
        self.platformFeeReceiver = params.platformFeeReceiver;
        self.eraSeconds = DEFAULT_ERA_SECONDS;
        self.offset = offset;
        self.minimalStake = params.minimalStake;
        self.platformFeeCommission = params.platformFeeCommission;
        self.rateChangeLimit = 5e10;
        self.validators = params.validators;
        self.unbondingPeriod = unbondingPeriod;
        self.unstakeTimesLimit = 20;
        self.paused = false;
    }
}
