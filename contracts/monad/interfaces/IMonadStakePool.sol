// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IMonadStakePool {
    function withdrawForStaker(address _staker, uint256 _amount) external;

    function delegateMulti(uint64[] calldata _validators, uint256 _amount) external;

    function undelegateMulti(uint64[] calldata _validators, uint256 _amount) external;

    function getDelegated(uint64 _validator) external returns (uint256);

    function getTotalDelegated(uint64[] calldata _validator) external returns (uint256);

    function withdrawMulti(uint64[] memory _validators) external;

    function compoundMulti(uint64[] memory _validators) external;
}
