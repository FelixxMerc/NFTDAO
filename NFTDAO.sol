// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTDAO {
    using SafeMath for uint256;

    string public name;
    IERC721 public nftContract;
    address public owner;
    uint256 public proposalCount;

    mapping(address => bool) public isMember;
    address[] public memberList;

    struct Proposal {
        address proposer;
        string name;
        string description;
        uint256 tokenId;
        address recipient;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        mapping(address => bool) votes;
    }

    mapping(uint256 => Proposal) public proposals;

    event AddMember(address indexed member);
    event RemoveMember(address indexed member);
    event CreateProposal(uint256 indexed proposalId, string name, string description, uint256 tokenId, address recipient);
    event VoteProposal(uint256 indexed proposalId, bool support);
    event ExecuteProposal(uint256 indexed proposalId);

    constructor(string memory _name, address _nftContract) {
        name = _name;
        nftContract = IERC721(_nftContract);
        owner = msg.sender;
        isMember[msg.sender] = true;
        memberList.push(msg.sender);
    }

    function addMember(address _member) external onlyOwner {
        require(!isMember[_member], "Already a member");
        isMember[_member] = true;
        memberList.push(_member);
        emit AddMember(_member);
    }

    function removeMember(address _member) external onlyOwner {
        require(isMember[_member], "Not a member");
        require(_member != owner, "Cannot remove owner");
        isMember[_member] = false;
        for (uint256 i = 0; i < memberList.length; i++) {
            if (memberList[i] == _member) {
                memberList[i] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
        emit RemoveMember(_member);
    }

    function createProposal(string memory _name, string memory _description, uint256 _tokenId, address _recipient)
        external
        onlyMember
        returns (uint256)
    {
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        Proposal storage newProposal = proposals[proposalCount];
        newProposal.proposer = msg.sender;
        newProposal.name = _name;
        newProposal.description = _description;
        newProposal.tokenId = _tokenId;
        newProposal.recipient = _recipient;

        proposalCount++;

        emit CreateProposal(proposalCount-1, newProposal.name, newProposal.description, newProposal.tokenId, newProposal.recipient);

        return proposalCount-1;
    }

    function voteOnProposal(uint256 _proposalId, bool _support) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.votes[msg.sender], "Already voted");

        proposal.votes[msg.sender] = true;
        if (_support) {
            proposal.yesVotes = proposal.yesVotes.add(1);
        } else {
            proposal.noVotes = proposal.noVotes.add(1);
        }

        emit VoteProposal(_proposalId, _support);
    }

    function executeProposal(uint256 _proposalId) external onlyMember {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.yesVotes.add(proposal.noVotes);
        require(totalVotes > 0, "No votes cast");

        if (proposal.yesVotes.mul(100).div(totalVotes) > 50) {
            nftContract.safeTransferFrom(address(this), proposal.recipient, proposal.tokenId);
            proposal.executed = true;
            emit ExecuteProposal(_proposalId);
        }
    }

    function getMemberCount() external view returns (uint256) {
        return memberList.length;
    }

    function getMemberAtIndex(uint256 _index) external view returns (address) {
        return memberList[_index];
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can perform this action");
        _;
    }
}
