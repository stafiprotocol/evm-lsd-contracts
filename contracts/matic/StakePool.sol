// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IValidatorShare.sol";
import "./interfaces/IGovStakeManager.sol";
import "./interfaces/IMaticStakePool.sol";
import "../base/Ownable.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, IMaticStakePool {
    // Custom errors to provide more descriptive revert messages.
    error FailedToWithdrawForStaker();

    using SafeERC20 for IERC20;

    address public stakeManagerAddress;
    address public govStakeManagerAddress;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert CallerNotAllowed();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stakeManagerAddress,
        address _govStakeManagerAddress,
        address _owner
    ) external initializer {
        if (_stakeManagerAddress == address(0) || _govStakeManagerAddress == address(0) || _owner == address(0)) {
            revert AddressNotAllowed();
        }

        stakeManagerAddress = _stakeManagerAddress;
        govStakeManagerAddress = _govStakeManagerAddress;

        _transferOwnership(_owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getDelegated(uint256 _validator) external view override returns (uint256) {
        address valAddress = IGovStakeManager(govStakeManagerAddress).getValidatorContract(_validator);
        (uint256 totalStake, ) = IValidatorShare(valAddress).getTotalStake(address(this));
        return totalStake;
    }

    function getTotalDelegated(uint256[] calldata _validators) external view override returns (uint256) {
        uint256 totalStake;
        IGovStakeManager govStakeManager = IGovStakeManager(govStakeManagerAddress);
        for (uint256 j = 0; j < _validators.length; ++j) {
            address valAddress = govStakeManager.getValidatorContract(_validators[j]);
            (uint256 stake, ) = IValidatorShare(valAddress).getTotalStake(address(this));
            totalStake = totalStake + stake;
        }
        return totalStake;
    }

    // ------------ stakeManager ------------

    function checkAndWithdrawRewards(
        uint256[] calldata _validators
    ) external override onlyStakeManager returns (uint256) {
        uint256 poolNewReward;
        IGovStakeManager govStakeManager = IGovStakeManager(govStakeManagerAddress);
        for (uint256 j = 0; j < _validators.length; ++j) {
            address valAddress = govStakeManager.getValidatorContract(_validators[j]);
            uint256 reward = IValidatorShare(valAddress).getLiquidRewards(address(this));
            if (reward > 0) {
                IValidatorShare(valAddress).buyVoucherPOL(0, 0);
                poolNewReward = poolNewReward + reward;
            }
        }
        return poolNewReward;
    }

    function delegate(
        uint256 _validator,
        uint256 _amount
    ) external override onlyStakeManager returns (uint256 amountToDeposit) {
        address valAddress = IGovStakeManager(govStakeManagerAddress).getValidatorContract(_validator);
        return IValidatorShare(valAddress).buyVoucherPOL(_amount, 0);
    }

    function undelegate(uint256 _validator, uint256 _claimAmount) external override onlyStakeManager {
        address valAddress = IGovStakeManager(govStakeManagerAddress).getValidatorContract(_validator);
        IValidatorShare(valAddress).sellVoucher_newPOL(_claimAmount, _claimAmount);
    }

    function unstakeClaimTokens(
        uint256 _validator,
        uint256 _claimedNonce
    ) external override onlyStakeManager returns (uint256) {
        IGovStakeManager govStakeManager = IGovStakeManager(govStakeManagerAddress);
        address valAddress = govStakeManager.getValidatorContract(_validator);
        uint256 willClaimedNonce = _claimedNonce + 1;
        IValidatorShare.DelegatorUnbond memory unbond = IValidatorShare(valAddress).unbonds_new(
            address(this),
            willClaimedNonce
        );

        if (unbond.withdrawEpoch == 0) {
            return _claimedNonce;
        }
        if (unbond.shares == 0) {
            return willClaimedNonce;
        }

        uint256 withdrawDelay = govStakeManager.withdrawalDelay();
        uint256 epoch = govStakeManager.epoch();
        if (unbond.withdrawEpoch + withdrawDelay > epoch) {
            return _claimedNonce;
        }

        IValidatorShare(valAddress).unstakeClaimTokens_newPOL(willClaimedNonce);

        return willClaimedNonce;
    }

    function withdrawForStaker(
        address _erc20TokenAddress,
        address _staker,
        uint256 _amount
    ) external override onlyStakeManager {
        if (_amount > 0) {
            IERC20(_erc20TokenAddress).safeTransfer(_staker, _amount);
        }
    }

    function redelegate(
        uint256 _fromValidatorId,
        uint256 _toValidatorId,
        uint256 _amount
    ) external override onlyStakeManager {
        IGovStakeManager(govStakeManagerAddress).migrateDelegation(_fromValidatorId, _toValidatorId, _amount);
    }

    function approveForStakeManager(address _erc20TokenAddress, uint256 amount) external override onlyStakeManager {
        IERC20(_erc20TokenAddress).safeIncreaseAllowance(govStakeManagerAddress, amount);
    }
}
