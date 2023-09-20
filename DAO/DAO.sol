// SPDX-License-Identifier: GPL-3.0-or-later
// Ben Grant (bwg9sbe)

pragma solidity ^0.8.16;

import "./IDAO.sol";
import "./IERC165.sol";
import "./IERC721Metadata.sol";
import "./NFTManager.sol";

contract DAO is IDAO {
    // getter functions for public variables
    address public nftmanager;
    uint public override minProposalDebatePeriod;
    address public override tokens;
    string public override purpose;
    mapping (uint => Proposal) public override proposals;

    mapping (address => mapping (uint => bool)) public override votedYes;
    mapping (address => mapping (uint => bool)) public override votedNo;

    uint public override numberOfProposals;
    string public override howToJoin;
    uint public override reservedEther;
    address public override curator;

    constructor () {
        minProposalDebatePeriod = 0;
        purpose = "Merry Christmas you filthy animal";
        howToJoin = "Become a filthy animal";
        reservedEther = 0;
        tokens = address(new NFTManager("Ben's NFT Manager", "BNFTM"));
        numberOfProposals = 0;
        curator = msg.sender;
    }

    function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++)
            result[i-startIndex] = strBytes[i];
        return string(result);
    }

    function addMember(address member) external override {
        require(msg.sender == curator || IERC721Metadata(tokens).balanceOf(msg.sender) > 0, "Sender needs to be part of the DAO");
        require(IERC721Metadata(tokens).balanceOf(member) == 0, "Member is already part of the DAO");

        string memory uri = substring(Strings.toHexString(member),2,34);
        NFTManager nft = NFTManager(tokens);
        nft.mintWithURI(member, uri);
    }

    function isMember(address member) external view override returns (bool) {
        NFTManager nft = NFTManager(tokens);
        if (member == curator) {
            return true;
        }
        return nft.balanceOf(member) > 0;
    }

    receive() external payable override {

    }

    function newProposal(address recipient, uint amount, string memory description, uint debatingPeriod) external payable override returns (uint) {
        require(debatingPeriod >= minProposalDebatePeriod, "Debating period is too short");
        
        reservedEther += amount;
        proposals[numberOfProposals] = Proposal(recipient, amount, description, block.timestamp + debatingPeriod, true, false, 0, 0, msg.sender);
        numberOfProposals++;
        emit NewProposal(numberOfProposals-1, recipient, amount, description);
        return numberOfProposals - 1;
    }

    function vote(uint proposalID, bool supportsProposal) external override {
        require(proposals[proposalID].open, "Proposal is closed");
        require(block.timestamp < proposals[proposalID].votingDeadline, "Voting deadline has passed");
        require(msg.sender == curator || NFTManager(tokens).balanceOf(msg.sender) > 0, "Sender is not part of the DAO");

        if (supportsProposal) {
            require(!votedYes[msg.sender][proposalID], "Sender already voted yes");

            votedYes[msg.sender][proposalID] = true;
            proposals[proposalID].yea++;
        } else {
            require(!votedNo[msg.sender][proposalID], "Sender already voted no");

            votedNo[msg.sender][proposalID] = true;
            proposals[proposalID].nay++;
        }
        emit Voted(proposalID, supportsProposal, msg.sender);
    }

    function closeProposal(uint proposalID) external override {
        require(proposals[proposalID].open, "Proposal is closed");
        require(block.timestamp >= proposals[proposalID].votingDeadline, "The deadline to vote has not passed");
        require(msg.sender == curator || NFTManager(tokens).balanceOf(msg.sender) > 0, "Sender is not part of the DAO");

        proposals[proposalID].open = false;
        if (proposals[proposalID].yea > proposals[proposalID].nay) {
            proposals[proposalID].proposalPassed = true;

            payable(proposals[proposalID].recipient).transfer(proposals[proposalID].amount);
            reservedEther -= proposals[proposalID].amount;
        }
        emit ProposalClosed(proposalID, proposals[proposalID].proposalPassed);
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IDAO).interfaceId;
    }

    function requestMembership() external pure override {
        revert("Did not have to do anything here");
    }

}