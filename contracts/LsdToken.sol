pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/IRateProvider.sol";

contract LsdToken is ERC20Burnable, IRateProvider {
    address public stakeManagerAddress;

    // Construct
    constructor(
        address _stakeManagerAddress,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        stakeManagerAddress = _stakeManagerAddress;
    }

    function getRate() external view override returns (uint256) {
        return IRateProvider(stakeManagerAddress).getRate();
    }

    // Mint lsdToken
    // Only accepts calls from the StakeManager contract
    function mint(address _to, uint256 _amount) external {
        require(msg.sender == stakeManagerAddress, "not manager");
        // Check lsdToken amount
        require(_amount > 0, "Invalid token mint amount");
        // Update balance & supply
        _mint(_to, _amount);
    }
}
