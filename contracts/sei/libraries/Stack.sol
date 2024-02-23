pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only
import "../StakePool.sol";

library Stack {
    error EntrustedPoolDuplicated();

    uint256 public constant DEFAULT_ERA_SECONDS = 86400;
    struct State {
        address admin;
        address stackFeeReceiver;
        address govStakingAddr; // to facilitate testing
        address govDistributionAddr; // to facilitate testing
        uint256 stackFeeCommission;
        uint256 totalStackFee;
        address[] entrustedPools;
        uint8 unbondingPeriod; // to facilitate testing
    }

    struct InitParams {
        address admin;
        address stackFeeReceiver;
        address govStakingAddr;
        address govDistributionAddr;
        uint8 unbondingPeriod;
    }

    function init(State storage self, InitParams memory params) internal {
        self.admin = params.admin;
        self.govStakingAddr = params.govStakingAddr;
        self.govDistributionAddr = params.govDistributionAddr;
        self.stackFeeReceiver = params.stackFeeReceiver;
        self.stackFeeCommission = 1e17;
        self.unbondingPeriod = params.unbondingPeriod;
    }

    struct ConfigStackParams {
        address stackFeeReceiver;
        uint256 stackFeeCommission;
        address addEntrustedPool;
        address removeEntrustedPool;
    }

    function configStack(State storage self, ConfigStackParams memory params) internal {
        if (params.stackFeeReceiver != address(0)) {
            self.stackFeeReceiver = params.stackFeeReceiver;
        }

        if (params.stackFeeCommission != 0) {
            self.stackFeeCommission = params.stackFeeCommission;
        }

        if (params.addEntrustedPool != address(0)) {
            for (uint256 i = 0; i < self.entrustedPools.length; i++) {
                if (self.entrustedPools[i] == params.addEntrustedPool) {
                    revert EntrustedPoolDuplicated();
                }
            }
            self.entrustedPools.push(params.addEntrustedPool);
        }

        if (params.removeEntrustedPool != address(0)) {
            for (uint256 i = 0; i < self.entrustedPools.length; i++) {
                if (self.entrustedPools[i] == params.removeEntrustedPool) {
                    self.entrustedPools[i] = self.entrustedPools[self.entrustedPools.length - 1];
                    self.entrustedPools.pop();
                }
            }
        }
    }
}
