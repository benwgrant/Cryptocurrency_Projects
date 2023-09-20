// SPDX-License-Identifier: GPL-3.0-or-later
// Ben Grant (bwg9sbe)

pragma solidity ^0.8.16;

import "./IAuctioneer.sol";
import "./IERC165.sol";
import "./INFTManager.sol";
import "./NFTManager.sol";


contract Auctioneer is IAuctioneer {
    address public override nftmanager;
    uint public override num_auctions;
    uint public override totalFees;
    uint public override unpaidFees;
    mapping (uint => Auction) public override auctions;
    address public override deployer;

    constructor() {
        deployer = msg.sender;
        nftmanager = address(new NFTManager("Ben's NFT Manager", "BNFTM"));
    }

    function collectFees() external override {
        require(msg.sender == deployer, "The deployer is the only one able to collect fees");
        (bool success, ) = payable(deployer).call{value: unpaidFees}("");
        require(success, "Failed to transfer fees to deployer");
        unpaidFees = 0;
    }

    function startAuction(uint m, uint h, uint d, string memory data, uint reserve, uint nftid) external override returns (uint) {
        require(msg.sender == INFTManager(nftmanager).ownerOf(nftid), "Only the owner of the NFT can start an auction");
        require(m > 0 || h > 0 || d > 0, "Auction must last longer than 0 minutes");
        require(reserve >= 0, "Reserve price must be greater than 0");

        // transfer NFT to this contract, revert if it can't
        NFTManager nft = NFTManager(nftmanager);
        nft.transferFrom(msg.sender, address(this), nftid);

        auctions[num_auctions] = Auction(num_auctions, 0, data, reserve, address(0), msg.sender, nftid, block.timestamp + m*60 + h*3600 + d*86400, true);
        num_auctions++;
        emit auctionStartEvent(num_auctions - 1);
        return num_auctions - 1;
    }

    function closeAuction(uint auctionid) external override {
        require(auctions[auctionid].active == true, "Auction is already closed");
        require(block.timestamp > auctions[auctionid].endTime, "Auction is still active");
        auctions[auctionid].active = false;
        // If there are no bids, then NFT ownership is transferred to the initiator
        if (auctions[auctionid].num_bids == 0) {
            NFTManager nft = NFTManager(nftmanager);
            nft.transferFrom(address(this), auctions[auctionid].initiator, auctions[auctionid].nftid);
        }
        // If there are bids, then NFT ownership is transferred to the highest bidder
        else {
            NFTManager nft = NFTManager(nftmanager);
            nft.transferFrom(address(this), auctions[auctionid].winner, auctions[auctionid].nftid);
            // Calculate fees
            uint fees = auctions[auctionid].highestBid / 100;
            unpaidFees += fees;
            totalFees += fees;
        }
        emit auctionCloseEvent(auctionid);
    }

    function placeBid(uint auctionid) external payable override {
        require(auctions[auctionid].active == true, "The auction is closed");
        require(block.timestamp < auctions[auctionid].endTime, "The auction is over");
        require(msg.value > auctions[auctionid].highestBid, "Bid must be higher than current highest bid");

        if (auctions[auctionid].num_bids > 0) {
            (bool success, ) = payable(auctions[auctionid].winner).call{value: auctions[auctionid].highestBid}("");
            require(success, "Failed to refund highest bid");
        }

        auctions[auctionid].highestBid = msg.value;
        auctions[auctionid].winner = msg.sender;
        auctions[auctionid].num_bids++;

        emit higherBidEvent(auctionid);
    }

    // Supportinterface for ERC165 and IAuctioneer
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IAuctioneer).interfaceId;
    }

    function auctionTimeLeft(uint auctionid) external view override returns (uint) {
        if (block.timestamp > auctions[auctionid].endTime) {
            return 0;
        }
        else {
            return auctions[auctionid].endTime - block.timestamp;
        }
    }
    
}