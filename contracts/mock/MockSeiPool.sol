pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

interface IGovStaking {
    function delegate(string memory valAddress) external payable returns (bool success);

    function redelegate(
        string memory srcAddress,
        string memory dstAddress,
        uint256 amount
    ) external returns (bool success);

    function undelegate(string memory valAddress, uint256 amount) external returns (bool success);
}

interface IGovDistribution {
    function setWithdrawAddress(address withdrawAddr) external returns (bool success);

    function withdrawDelegationRewards(string memory validator) external returns (bool success);
}

contract MockSeiPool {
    address govStakingAddress = 0x0000000000000000000000000000000000001005;
    address govDistributionAddress = 0x0000000000000000000000000000000000001007;

    function delegate(string memory _validator) external payable {
        IGovStaking(govStakingAddress).delegate{value: msg.value}(_validator);
    }

    function undelegate(string memory _validator, uint256 _amount) external {
        IGovStaking(govStakingAddress).undelegate(_validator, _amount);
    }

    function setWithdrawAddress(address _withdrawAddress) external {
        IGovDistribution(govDistributionAddress).setWithdrawAddress(_withdrawAddress);
    }
}
