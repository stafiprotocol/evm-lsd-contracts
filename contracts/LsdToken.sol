// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/IRateProvider.sol";

contract LsdToken is ERC20Burnable, ILsdToken, IRateProvider {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error ZeroMintAmount();
    error StakeManagerInitialized();

    address public stakeManagerAddress;

    // Construct
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function getRate() public view override returns (uint256) {
        return IRateProvider(stakeManagerAddress).getRate();
    }

    function initStakeManager(address _stakeManagerAddress) external override {
        if (stakeManagerAddress != address(0)) {
            revert StakeManagerInitialized();
        }

        stakeManagerAddress = _stakeManagerAddress;
    }

    // Mint lsdToken
    // Only accepts calls from the StakeManager contract
    function mint(address _to, uint256 _amount) public override {
        if (stakeManagerAddress != msg.sender) revert NotStakeManager();
        // Check lsdToken amount
        if (_amount == 0) revert ZeroMintAmount();
        // Update balance & supply
        _mint(_to, _amount);
    }
}
