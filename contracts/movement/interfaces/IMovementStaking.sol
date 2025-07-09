// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IMovementStaking {
    function getEpochByBlockTime(address) external view returns (uint256);

    function getCurrentEpoch(address) external view returns (uint256);

    function getNextEpoch(address) external view returns (uint256);

    function getNextEpochByBlockTime(address) external view returns (uint256);

    function getStakeAtEpoch(address domain, uint256 epoch, address custodian, address attester)
        external
        view
        returns (uint256);

    function getCurrentEpochStake(address domain, address custodian, address attester)
        external
        view
        returns (uint256);

    function getUnstakeAtEpoch(address domain, uint256 epoch, address custodian, address attester)
        external
        view
        returns (uint256);

    function getCurrentEpochUnstake(address domain, address custodian, address attester)
        external
        view
        returns (uint256);

    function stake(address domain, IERC20 custodian, uint256 amount) external;

    function unstake(address domain, address custodian, uint256 amount) external;
}
