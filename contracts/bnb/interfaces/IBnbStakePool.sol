// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IBnbStakePool {
    function redelegate(address _validatorSrc, address _validatorDst, uint256 _amount) external payable;

    function withdrawForStaker(address _staker, uint256 _amount) external;

    function delegateMulti(address[] calldata _validators, uint256 _amount) external;

    function undelegateMulti(address[] calldata _validators, uint256 _amount) external;

    function getDelegated(address _validator) external view returns (uint256);

    function getTotalDelegated(address[] calldata _validator) external view returns (uint256);

    function claimUndelegated(address[] memory _validators) external;
}
