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

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableStringSet for EnumerableStringSet.StringSet;

    uint256 constant TWELVE_DECIMALS = 1e12;

    mapping(address => EnumerableStringSet.StringSet) validatorsOf;

    // events
    event Stake(address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount);
    event Unstake(
        address staker, address poolAddress, uint256 tokenAmount, uint256 lsdTokenAmount, uint256 unstakeIndex
    );
    event Withdraw(address staker, address poolAddress, uint256 tokenAmount, int256[] unstakeIndexList);
    event ExecuteNewEra(uint256 indexed era, uint256 rate);
    event Delegate(address pool, string[] validators, uint256 amount);
    event Undelegate(address pool, string[] validators, uint256 amount);
    event NewReward(address pool, uint256 amount);
    event ServiceTerminated();
    event UnstakeAndWithdraw(address staker, address poolAddress, uint256 lsdTokenAmount, uint256 tokenAmount);
    event AdminWithdraw(address staker, address poolAddress, uint256 tokenAmount);

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

    // ------------ service termination ------------
    function terminateService() external onlyOwner {
        _manualUndelegateAll();
        emit ServiceTerminated();
    }

    function _manualUndelegateAll() internal {
        address _poolAddress = bondedPools.at(0);
        string[] memory validators = getValidatorsOf(_poolAddress);
        ISeiStakePool(_poolAddress).withdrawDelegationRewardsMulti(validators);

        uint256 totalDelegated = ISeiStakePool(_poolAddress).getTotalDelegated(validators);
        ISeiStakePool(_poolAddress).undelegateMulti(validators, totalDelegated);

        emit Undelegate(_poolAddress, validators, totalDelegated);
    }

    function adminWithdraw(address _poolAddress, uint256 _amount) external onlyOwner {
        ISeiStakePool(_poolAddress).withdrawForStaker(msg.sender, _amount);
        emit AdminWithdraw(msg.sender, _poolAddress, _amount);
    }


    // ----- staker operation
    function unstakeAndWithdrawAll() external {
        address _poolAddress = bondedPools.at(0);
        uint256 _lsdTokenAmount = IERC20(lsdToken).balanceOf(msg.sender);
        if (_lsdTokenAmount == 0) revert ZeroUnstakeAmount();

        uint256 tokenAmount = (_lsdTokenAmount * rate) / EIGHTEEN_DECIMALS;
        /// forge-lint: disable-next-line(divide-before-multiply)
        tokenAmount = (tokenAmount / TWELVE_DECIMALS) * TWELVE_DECIMALS;

        // burn lsdToken
        ERC20Burnable(lsdToken).burnFrom(msg.sender, _lsdTokenAmount);
        
        ISeiStakePool(_poolAddress).withdrawForStaker(msg.sender, tokenAmount);
        emit UnstakeAndWithdraw(msg.sender, _poolAddress, _lsdTokenAmount, tokenAmount);
    }
}
