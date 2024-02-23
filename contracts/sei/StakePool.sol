pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../base/Ownable.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ISeiStakePool.sol";
import "../LsdToken.sol";

contract StakePool is Initializable, UUPSUpgradeable, Ownable, ISeiStakePool {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error NotValidAddress();
    error FailedToWithdrawForStaker();

    uint256 public constant TEN_DECIMALS = 1e10;

    address public stakingAddress;
    address public stakeManagerAddress;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _stakingAddress,
        address _stakeManagerAddress,
        address _owner
    ) external virtual initializer {
        if (stakingAddress != address(0)) revert AlreadyInitialized();
        if (_stakeManagerAddress == address(0)) revert NotValidAddress();

        _transferOwnership(_owner);
        stakingAddress = _stakingAddress;
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function delegate(string memory validator, uint256 amount) external override onlyStakeManager {
        IStaking(stakingAddress).delegate(validator, amount);
    }

    function undelegate(string memory validator, uint256 amount) external override onlyStakeManager {
        IStaking(stakingAddress).undelegate(validator, amount);
    }

    function redelegate(
        string memory validatorSrc,
        string memory validatorDst,
        uint256 amount
    ) external override onlyStakeManager {
        IStaking(stakingAddress).redelegate(validatorSrc, validatorDst, amount);
    }

    function withdrawForStaker(address staker, uint256 amount) external override onlyStakeManager {
        if (amount > 0) {
            (bool result, ) = staker.call{value: amount}("");
            if (!result) revert FailedToWithdrawForStaker();
        }
    }

    function getDelegated(string memory validator) external view override returns (uint256) {
        return IStaking(stakingAddress).getDelegation(address(this), validator);
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
