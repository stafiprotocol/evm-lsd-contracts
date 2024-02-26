pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only
import "../StakePool.sol";

library Pool {
    uint256 public constant DEFAULT_ERA_SECONDS = 86400;
    uint256 public constant MIN_ERA_SECONDS = 28800; //8h
    uint256 public constant MAX_ERA_SECONDS = 86400; //24h

    error NotAllowedEraSeconds();

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
        uint256 unbondingSeconds
    ) internal {
        self.pool = stakePool;
        self.admin = msg.sender;
        self.lsdToken = lsdToken;
        self.platformFeeReceiver = params.platformFeeReceiver;
        self.eraSeconds = DEFAULT_ERA_SECONDS;
        self.minimalStake = params.minimalStake;
        self.platformFeeCommission = params.platformFeeCommission;
        self.rateChangeLimit = 0;
        self.validators = params.validators;
        self.unstakeTimesLimit = 20;
        self.paused = false;

        (self.unbondingPeriod, self.offset) = calUnbondingPeriodAndOffset(self, 0, unbondingSeconds);
    }

    struct ConfigPoolParams {
        address platformFeeReceiver;
        address newAdmin;
        uint256 minimalStake;
        uint256 eraSeconds;
        uint256 rateChangeLimit;
        uint8 unstakeTimesLimit;
    }

    function configPool(State storage self, ConfigPoolParams memory params, uint256 unbondingSeconds) internal {
        if (params.platformFeeReceiver != address(0)) {
            self.platformFeeReceiver = params.platformFeeReceiver;
        }
        if (params.newAdmin != address(0)) {
            self.admin = params.newAdmin;
        }
        if (params.minimalStake != 0) {
            self.minimalStake = params.minimalStake;
        }
        if (params.eraSeconds != 0) {
            if (params.eraSeconds < MIN_ERA_SECONDS || params.eraSeconds > MAX_ERA_SECONDS) {
                revert NotAllowedEraSeconds();
            }
            uint256 currentEra = calCurrentEra(self);

            self.eraSeconds = params.eraSeconds;
            (self.unbondingPeriod, self.offset) = calUnbondingPeriodAndOffset(self, currentEra, unbondingSeconds);
        }
        if (params.rateChangeLimit != 0) {
            self.rateChangeLimit = params.rateChangeLimit;
        }
        if (params.unstakeTimesLimit != 0) {
            self.unstakeTimesLimit = params.unstakeTimesLimit;
        }
    }

    function redelegate(
        State storage self,
        string memory _srcValidator,
        string memory _dstValidator,
        uint256 _amount
    ) external {}

    function stake(State storage self, uint256 _stakeAmount) internal {}

    function unstake(State storage self, uint256 _lsdTokenAmount) internal {}

    function withdraw(State storage self) internal {}

    function newEra(State storage self) internal {}

    // ------ getter -----
    function calCurrentEra(State storage self) internal view returns (uint256) {
        return uint256(int256(block.timestamp / self.eraSeconds) + self.offset);
    }

    function calUnbondingPeriodAndOffset(
        State storage self,
        uint256 currentEra,
        uint256 unbondingSeconds
    ) internal view returns (uint8, int256) {
        int256 offset = int256(currentEra) - int256(block.timestamp / self.eraSeconds);

        if (unbondingSeconds % self.eraSeconds == 0) {
            return (uint8(unbondingSeconds / self.eraSeconds) + 1, offset);
        } else {
            return (uint8(unbondingSeconds / self.eraSeconds) + 2, offset);
        }
    }
}
