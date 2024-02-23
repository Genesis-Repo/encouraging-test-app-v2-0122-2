// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 public feePercentage;   // Fee percentage to be set by the marketplace owner
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    struct Escrow {
        address buyer;
        uint256 amount;
        bool isFunded;
        bool isReleased;
    }

    mapping(address => mapping(uint256 => Listing)) private listings;
    mapping(address => mapping(uint256 => Escrow)) private escrows;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);
    event EscrowFunded(address indexed buyer, uint256 indexed tokenId, uint256 amount);
    event EscrowReleased(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 amount);

    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    // Function to list an NFT for sale
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new listing
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    // Function to buy an NFT listed on the marketplace
    function buyNFT(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT is not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        // Create an escrow for the buyer
        escrows[nftContract][tokenId] = Escrow({
            buyer: msg.sender,
            amount: msg.value,
            isFunded: true,
            isReleased: false
        });

        emit EscrowFunded(msg.sender, tokenId, msg.value);
    }

    // Function for the seller to release funds from escrow after buyer confirms receipt
    function releaseEscrow(address nftContract, uint256 tokenId) external {
        Escrow storage escrow = escrows[nftContract][tokenId];
        require(escrow.buyer == msg.sender, "You are not the buyer");
        require(escrow.isFunded, "Escrow is not funded");
        require(!escrow.isReleased, "Escrow has already been released");

        // Transfer the funds to the seller
        payable(listings[nftContract][tokenId].seller).transfer(escrow.amount);

        // Mark the escrow as released
        escrow.isReleased = true;

        // Transfer the NFT from the marketplace contract to the buyer
        IERC721(nftContract).safeTransferFrom(address(this), escrow.buyer, tokenId);

        // Update the listing
        listings[nftContract][tokenId].isActive = false;

        emit NFTSold(listings[nftContract][tokenId].seller, escrow.buyer, tokenId, listings[nftContract][tokenId].price);
        emit EscrowReleased(listings[nftContract][tokenId].seller, escrow.buyer, tokenId, escrow.amount);
    }

    // Function to change the price of a listed NFT
    function changePrice(address nftContract, uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than zero");
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        listings[nftContract][tokenId].price = newPrice;

        emit NFTPriceChanged(msg.sender, tokenId, newPrice);
    }

    // Function to unlist a listed NFT
    function unlistNFT(address nftContract, uint256 tokenId) external {
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        delete listings[nftContract][tokenId];

        // Transfer the NFT back to the seller
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NFTUnlisted(msg.sender, tokenId);
    }

    // Function to set the fee percentage by the marketplace owner
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }

    // Additional feature ideas:
    // {
    //     "short_name": "Auction",
    //     "description": "Implement an auction functionality where users can bid and the highest bidder wins."
    // },
    // {
    //     "short_name": "Statistics",
    //     "description": "Track statistics of the listings and sales of NFTs on the marketplace."
    // },
    // {
    //     "short_name": "Rating & Reviews",
    //     "description": "Introduce a rating and review system for buyers and sellers on the platform."
    // },
    // {
    //     "short_name": "Multiple Currencies",
    //     "description": "Integrate with external payment systems for multiple currency support."
    // },
    // {
    //     "short_name": "Escrow Timeouts",
    //     "description": "Implement escrow timeouts where funds are released if no action is taken within a set period."
    // }
}