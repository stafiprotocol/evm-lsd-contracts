// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBnbStakePool.sol";
import "../base/Manager.sol";

contract StakeManager is Initializable, Manager, UUPSUpgradeable {
    error ZeroUnstakeAmount();

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => EnumerableSet.AddressSet) validatorsOf;

    // events
    event ServiceTerminated();
    event UnstakeAndWithdraw(address staker, address poolAddress, uint256 lsdTokenAmount, uint256 tokenAmount);
    event AdminWithdraw(address admin, address poolAddress, uint256 tokenAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ------------ getter ------------

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }

    function getValidatorsOf(address _poolAddress) public view returns (address[] memory validators) {
        return validatorsOf[_poolAddress].values();
    }

    // ------ termination

    function terminateService() external onlyOwner {
        _terminateAllPools();
        emit ServiceTerminated();
    }

    function claimUndelegated(address _poolAddress) external onlyOwner {
        address[] memory validators = getValidatorsOf(_poolAddress);
        IBnbStakePool(_poolAddress).claimUndelegated(validators);
    }

    function adminWithdraw(address _poolAddress, uint256 _amount) external onlyOwner {
        IBnbStakePool(_poolAddress).withdrawForStaker(msg.sender, _amount);
        emit AdminWithdraw(msg.sender, _poolAddress, _amount);
    }

    function _terminateAllPools() internal {
        address[] memory poolList = getBondedPools();
        for (uint256 i = 0; i < poolList.length; ++i) {
            address poolAddress = poolList[i];
            IBnbStakePool stakePool = IBnbStakePool(poolAddress);
            address[] memory validators = getValidatorsOf(poolAddress);

            // claim any already undelegated BNB first
            stakePool.claimUndelegated(validators);

            // undelegate all delegated BNB
            uint256 totalDelegated = stakePool.getTotalDelegated(validators);
            if (totalDelegated > 0) {
                stakePool.undelegateMulti(validators, totalDelegated);
            }
        }
    }

    // ----- staker operation

    function unstakeAndWithdrawAll() external {
        uint256 lsdTokenAmount = ERC20Burnable(lsdToken).balanceOf(msg.sender);
        if (lsdTokenAmount == 0) revert ZeroUnstakeAmount();

        address poolAddress = bondedPools.at(0);
        uint256 tokenAmount = (lsdTokenAmount * rate) / EIGHTEEN_DECIMALS;

        // burn lsdToken
        ERC20Burnable(lsdToken).burnFrom(msg.sender, lsdTokenAmount);

        // update pool state
        PoolInfo storage poolInfo = poolInfoOf[poolAddress];
        poolInfo.active -= tokenAmount;

        IBnbStakePool(poolAddress).withdrawForStaker(msg.sender, tokenAmount);

        emit UnstakeAndWithdraw(msg.sender, poolAddress, lsdTokenAmount, tokenAmount);
    }
}
