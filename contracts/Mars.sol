// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Mars is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(string calldata _name) public initializer {
        __Ownable_init();
        __ERC20_init(_name, "MARS");

        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    function _authorizeUpgrade(address newImplementation) internal 
    override
    onlyOwner
    {

    }

    function version() public pure virtual returns (string memory) {
        return "v1";
    }
}

contract MarsV2 is Mars {
    uint256 fee;

    function version() public pure override returns (string memory) {
        return "v2";
    }
}