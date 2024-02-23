// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    // State variables and data structures for the auction functionality
    struct Auction {
        address seller;
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool isActive;
    }

    mapping(address => mapping(uint256 => Auction)) private auctions;

    event NFTAuctionStarted(address indexed seller, uint256 indexed tokenId, uint256 startingPrice, uint256 endTime);
    event NFTBidPlaced(address indexed bidder, uint256 indexed tokenId, uint256 amount);
    event NFTAuctionEnded(address indexed seller, address indexed winner, uint256 indexed tokenId, uint256 amount);

    // Function to start an auction for an NFT
    function startAuction(address nftContract, uint256 tokenId, uint256 startingPrice, uint256 duration) external {
        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Set up the auction details
        auctions[nftContract][tokenId] = Auction({
            seller: msg.sender,
            highestBidder: address(0),
            highestBid: startingPrice,
            endTime: block.timestamp + duration,
            isActive: true
        });

        emit NFTAuctionStarted(msg.sender, tokenId, startingPrice, auctions[nftContract][tokenId].endTime);
    }

    // Function for users to place a bid on an ongoing auction
    function placeBid(address nftContract, uint256 tokenId) external payable {
        Auction storage auction = auctions[nftContract][tokenId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        // Update the highest bidder and bid amount
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit NFTBidPlaced(msg.sender, tokenId, msg.value);
    }

    // Function to end an auction and transfer the NFT to the highest bidder
    function endAuction(address nftContract, uint256 tokenId) external {
        Auction storage auction = auctions[nftContract][tokenId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp >= auction.endTime, "Auction is ongoing");

        // Transfer the NFT to the highest bidder
        IERC721(nftContract).safeTransferFrom(address(this), auction.highestBidder, tokenId);

        // Transfer the funds from the highest bidder to the seller after deducting the fee
        uint256 fee = (auction.highestBid * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = auction.highestBid - fee;

        payable(auction.seller).transfer(sellerAmount);

        // End the auction and update state
        auction.isActive = false;

        emit NFTAuctionEnded(auction.seller, auction.highestBidder, tokenId, auction.highestBid);
    }

    // Additional feature ideas:
    // {
    //     "short_name": "Statistics",
    //     "description": "Track statistics of the listings, sales, and auction results of NFTs on the marketplace."
    // },
    // {
    //     "short_name": "Rating & Reviews",
    //     "description": "Introduce a rating and review system for buyers and sellers in the marketplace."
    // },
    // {
    //     "short_name": "Multiple Currencies",
    //     "description": "Integrate with external payment systems for multiple currency support."
    // },
    // {
    //     "short_name": "Escrow Timeouts",
    //     "description": "Implement escrow timeouts where funds are released if no action is taken within a set period."
    // },
    // {
    //     "short_name": "Instant Buy",
    //     "description": "Allow users to instantly purchase NFTs at a fixed price without auctions."
    // }
    // {
    //     "short_name": "Customizable Auction Parameters",
    //     "description": "Allow sellers to set custom parameters for the auction such as starting price, duration, etc."
    // }
}