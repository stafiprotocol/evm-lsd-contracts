// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IGovStaking {
    function delegate(string memory valAddress, uint256 amount) external returns (bool success);

    function redelegate(
        string memory srcAddress,
        string memory dstAddress,
        uint256 amount
    ) external returns (bool success);

    function undelegate(string memory valAddress, uint256 amount) external returns (bool success);

    function getDelegation(address delegator, string memory valAddress) external view returns (uint256 shares);
}
