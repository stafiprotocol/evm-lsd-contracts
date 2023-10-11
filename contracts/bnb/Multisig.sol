pragma solidity 0.8.19;

// SPDX-License-Identifier: GPL-3.0-only

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../base/Ownable.sol";

contract Multisig is Initializable, Ownable {
    // Custom errors to provide more descriptive revert messages.
    error NotVoter();
    error InvalidThreshold();
    error TooManyVoters();
    error NotEnoughVoters();
    error ProposalAlreadyExecuted(bytes32 proposalId);
    error AlreadyVoted();

    using SafeCast for *;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum ProposalStatus {
        Inactive,
        Active,
        Executed
    }

    struct Proposal {
        ProposalStatus _status;
        uint16 _yesVotes; // bitmap, 16 maximum votes
        uint8 _yesVotesTotal;
    }

    uint8 public threshold;
    EnumerableSet.AddressSet voters;

    mapping(bytes32 => Proposal) public proposals;

    event ProposalExecuted(bytes32 indexed proposalId);

    modifier onlyVoter() {
        if (!voters.contains(msg.sender)) revert NotVoter();
        _;
    }

    function initMultisig(address[] memory _voters, uint256 _initialThreshold) public virtual onlyInitializing {
        if (threshold != 0) revert AlreadyInitialized();
        if (!(_voters.length >= _initialThreshold && _initialThreshold > _voters.length / 2)) revert InvalidThreshold();
        if (_voters.length > 16) revert TooManyVoters();

        threshold = _initialThreshold.toUint8();
        uint256 initialVoterCount = _voters.length;
        for (uint256 i; i < initialVoterCount; ++i) {
            voters.add(_voters[i]);
        }
    }

    function addVoter(address _voter) public onlyOwner {
        if (voters.length() >= 16) revert TooManyVoters();
        if (threshold <= (voters.length() + 1) / 2) revert InvalidThreshold();

        voters.add(_voter);
    }

    function removeVoter(address _voter) public onlyOwner {
        if (voters.length() <= threshold) revert NotEnoughVoters();

        voters.remove(_voter);
    }

    function changeThreshold(uint256 _newThreshold) public onlyOwner {
        if (!(voters.length() >= _newThreshold && _newThreshold > voters.length() / 2)) revert InvalidThreshold();

        threshold = _newThreshold.toUint8();
    }

    function getVoterIndex(address _voter) public view returns (uint256) {
        return voters._inner._indexes[bytes32(uint256(uint160(_voter)))];
    }

    function voterBit(address _voter) internal view returns (uint256) {
        return uint256(1) << (getVoterIndex(_voter) - 1);
    }

    function _hasVoted(Proposal memory _proposal, address _voter) internal view returns (bool) {
        return (voterBit(_voter) & uint256(_proposal._yesVotes)) > 0;
    }

    function hasVoted(bytes32 _proposalId, address _voter) public view returns (bool) {
        Proposal memory proposal = proposals[_proposalId];
        return _hasVoted(proposal, _voter);
    }

    function _checkProposal(bytes32 _proposalId) internal view returns (Proposal memory proposal) {
        proposal = proposals[_proposalId];

        if (uint256(proposal._status) > 1) revert ProposalAlreadyExecuted(_proposalId);
        if (_hasVoted(proposal, msg.sender)) revert AlreadyVoted();

        if (proposal._status == ProposalStatus.Inactive) {
            proposal = Proposal({_status: ProposalStatus.Active, _yesVotes: 0, _yesVotesTotal: 0});
        }
        proposal._yesVotes = (proposal._yesVotes | voterBit(msg.sender)).toUint16();
        proposal._yesVotesTotal++;
    }
}
