pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/ILsdToken.sol";
import "./interfaces/IRateProvider.sol";

contract LsdToken is ERC20Burnable, ILsdToken, IRateProvider {
    // Custom errors to provide more descriptive revert messages.
    error NotStakeManager();
    error ZeroMintAmount();

    address public stakeManagerAddress;

    // Construct
    constructor(
        address _stakeManagerAddress,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        stakeManagerAddress = _stakeManagerAddress;
    }

    function getRate() public view override returns (uint256) {
        return IRateProvider(stakeManagerAddress).getRate();
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
