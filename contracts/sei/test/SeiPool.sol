pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

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

interface IGovDistribution {
    function setWithdrawAddress(address withdrawAddr) external returns (bool success);

    function withdrawDelegationRewards(string memory validator) external returns (bool success);
}

contract SeiPool {
    address govStakingAddress = 0x0000000000000000000000000000000000001005;
    address govDistributionAddress = 0x0000000000000000000000000000000000001007;

    receive() external payable {}

    function delegate(string memory _validator, uint256 _amount) external payable {
        IGovStaking(govStakingAddress).delegate(_validator, _amount);
    }

    function setWithdrawAddress(address _withdrawAddress) external {
        IGovDistribution(govDistributionAddress).setWithdrawAddress(_withdrawAddress);
    }
}
