pragma solidity 0.8.19;
// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../base/Ownable.sol";
import "./interfaces/ISeiWithdrawPool.sol";

contract WithdrawPool is Initializable, UUPSUpgradeable, Ownable, ISeiWithdrawPool {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error NotValidAddress();
    error FailedToWithdrawReward();

    address public stakeManagerAddress;

    modifier onlyStakeManager() {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeManagerAddress, address _owner) external virtual initializer {
        if (_stakeManagerAddress == address(0)) revert NotValidAddress();

        _transferOwnership(_owner);
        stakeManagerAddress = _stakeManagerAddress;
    }

    receive() external payable {}

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    function withdrawReward(address _to, uint256 _amount) external override onlyStakeManager {
        if (_amount > 0) {
            (bool result, ) = _to.call{value: _amount}("");
            if (!result) revert FailedToWithdrawReward();
        }
    }

    function version() external view returns (uint8) {
        return _getInitializedVersion();
    }
}
