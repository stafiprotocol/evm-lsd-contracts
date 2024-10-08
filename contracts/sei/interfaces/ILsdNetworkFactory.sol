// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "../../base/Errors.sol";

interface ILsdNetworkFactory is Errors {
    struct NetworkContracts {
        address _stakeManager;
        address _stakePool;
        address _lsdToken;
        uint256 _block;
    }

    event LsdNetwork(NetworkContracts contracts);

    function createLsdNetwork(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        string[] memory _validators,
        address _networkAdmin
    ) external;

    function createLsdNetworkWithTimelock(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        string[] memory _validators,
        uint256 minDelay,
        address[] memory proposers
    ) external;

    function createLsdNetworkWithLsdToken(
        address _lsdToken,
        string[] memory _validators,
        address _networkAdmin
    ) external;
}
