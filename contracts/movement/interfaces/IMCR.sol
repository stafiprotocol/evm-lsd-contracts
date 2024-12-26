// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

interface IMCR {
    struct BlockCommitment {
        uint256 height;
        bytes32 commitment;
        bytes32 blockId;
    }

    function submitBlockCommitment(BlockCommitment memory blockCommitment) external;

    function submitBatchBlockCommitment(BlockCommitment[] memory blockCommitments) external;
}
