// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../monad/interfaces/IMonadStaking.sol";

contract StakePool {
    // Custom errors to provide more descriptive revert messages.
    error AmountZero();
    error FailedToWithdrawForStaker();
    error FailedDelegate();
    error FailedUndelegate();
    error FailedCompound();
    error FailedWithdraw();
    error DuplicateWithdrawalId();
    error NotEnoughAmountToUndelegate();
    error NotEnoughRedelegateFee();

    event Delegate(uint64 validator, uint256 amount);
    event Undelegate(uint64 validator, uint256 amount);
    event WithdrawForStaker(address staker, uint256 amount);
    event ClaimUndelegated(uint64 validator, uint64 withdrawId);

    using EnumerableSet for EnumerableSet.UintSet;

    IMonadStaking public constant MONAD_STAKIING = IMonadStaking(0x0000000000000000000000000000000000001000);
    uint64 public constant WITHDRAWAL_DELAY = 1;

    address public stakeManagerAddress;
    uint256 public lastUndelegateIndex;

    mapping(uint64 => EnumerableSet.UintSet) _pendingWithdrawals;
    mapping(uint64 => uint8) _nextWithdrawId;

    constructor() {}

    receive() external payable {}

    // ------------ getter ------------

    function getPendingWithdrawals(uint64 _validator) public view returns (uint8[] memory withdrawals) {
        uint256[] memory vals256 = _pendingWithdrawals[_validator].values();
        withdrawals = new uint8[](vals256.length);

        for (uint256 i = 0; i < vals256.length; i++) {
            withdrawals[i] = uint8(vals256[i]);
        }
    }

    function getDelegated(uint64 _validator) public returns (uint256) {
        (uint256 stake,,, uint256 deltaStake, uint256 nextDeltaStake,,) =
            MONAD_STAKIING.getDelegator(_validator, address(this));
        return stake + deltaStake + nextDeltaStake;
    }

    function getActived(uint64 _validator) public returns (uint256) {
        (uint256 stake,,,,,,) = MONAD_STAKIING.getDelegator(_validator, address(this));
        return stake;
    }

    function getTotalDelegated(uint64[] calldata _validators) external returns (uint256) {
        uint256 totalAmount;
        for (uint256 i = 0; i < _validators.length; ++i) {
            totalAmount += getDelegated(_validators[i]);
        }
        return totalAmount;
    }

    // ------------ stakeManager ------------

    function _govDelegate(uint64 _validator, uint256 _amount) internal {
        bool success = MONAD_STAKIING.delegate{value: _amount}(_validator);
        if (!success) revert FailedDelegate();

        emit Delegate(_validator, _amount);
    }

    function _govUndelegate(uint64 _validator, uint256 _amount) internal {
        uint8 withdrawId = _nextWithdrawId[_validator];

        if (withdrawId < 255) {
            _nextWithdrawId[_validator] = withdrawId + 1;
        } else {
            _nextWithdrawId[_validator] = 0;
        }

        if (!_pendingWithdrawals[_validator].add(uint256(withdrawId))) revert DuplicateWithdrawalId();

        bool success = MONAD_STAKIING.undelegate(_validator, _amount, withdrawId);
        if (!success) revert FailedUndelegate();

        emit Undelegate(_validator, _amount);
    }

    function _govWithdraw(uint64 _validator) internal {
        uint8[] memory withdrawals = getPendingWithdrawals(_validator);
        (uint64 epoch,) = MONAD_STAKIING.getEpoch();
        for (uint256 i = 0; i < withdrawals.length; i++) {
            (,, uint64 withdrawEpoch) = MONAD_STAKIING.getWithdrawalRequest(_validator, address(this), withdrawals[i]);
            if (withdrawEpoch + 2 + WITHDRAWAL_DELAY >= epoch) {
                bool success = MONAD_STAKIING.withdraw(_validator, withdrawals[i]);
                if (!success) revert FailedWithdraw();

                _pendingWithdrawals[_validator].remove(withdrawals[i]);
                emit ClaimUndelegated(_validator, withdrawals[i]);
            }
        }
    }

    function _govCompound(uint64 _validator) internal {
        (,, uint256 reward,,,,) = MONAD_STAKIING.getDelegator(_validator, address(this));
        if (reward == 0) return;

        bool success = MONAD_STAKIING.compound(_validator);
        if (!success) revert FailedCompound();
    }

    function TestDelegateAndGet(uint64 _validator) public payable {
        bool success = MONAD_STAKIING.delegate{value: msg.value}(_validator);
        if (!success) revert FailedDelegate();

        emit Delegate(_validator, msg.value);

        uint256 delegated = getDelegated(_validator);

        emit Delegate(_validator, delegated);
    }

    function TestDelegate(uint64 _validator) public payable {
        bool success = MONAD_STAKIING.delegate{value: msg.value}(_validator);
        if (!success) revert FailedDelegate();

        emit Delegate(_validator, msg.value);
    }

    function TestCompound(uint64 _validator) public {
        _govCompound(_validator);
    }
}
