pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../StakePool.sol";

library NewContract {
    function newLsdToken(
        address _stakeManagerAddress,
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol
    ) public returns (address) {
        return address(new LsdToken(_stakeManagerAddress, _lsdTokenName, _lsdTokenSymbol));
    }

    function newERC1967Proxy(address _logicAddress) public returns (address) {
        return address(new ERC1967Proxy(_logicAddress, ""));
    }
}
