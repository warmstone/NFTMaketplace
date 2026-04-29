// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTMarketplaceUpgradeable} from "./NFTMarketplaceUpgradeable.sol";

/// @notice V2 upgrade that adds ERC20 fixed-price purchases and auctions.
contract NFTMarketplaceUpgradeableV2 is NFTMarketplaceUpgradeable {
    using SafeERC20 for IERC20;

    struct ERC20Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 price;
        bool active;
    }

    struct ERC20Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool active;
    }

    mapping(address => bool) public paymentTokenAllowed;
    mapping(uint256 => ERC20Listing) public erc20Listings;
    uint256 public erc20ListingCounter;
    mapping(uint256 => ERC20Auction) public erc20Auctions;
    uint256 public erc20AuctionCounter;
    mapping(uint256 => mapping(address => uint256)) public erc20PendingReturns;

    error PaymentTokenNotAllowed();

    event PaymentTokenAllowedUpdated(address indexed token, bool allowed);
    event ERC20NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 price
    );
    event ERC20NFTSold(
        uint256 indexed listingId, address indexed buyer, address indexed seller, address paymentToken, uint256 price
    );
    event ERC20AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 startPrice,
        uint256 endTime
    );
    event ERC20BidPlaced(
        uint256 indexed auctionId, address indexed bidder, address indexed paymentToken, uint256 bidAmount
    );
    event ERC20AuctionEnded(
        uint256 indexed auctionId, address indexed buyer, address indexed paymentToken, uint256 price
    );
    event ERC20BidWithdrawn(
        uint256 indexed auctionId, address indexed bidder, address indexed paymentToken, uint256 amount
    );

    function version() external pure virtual returns (string memory) {
        return "2.0.0";
    }

    function setPaymentTokenAllowed(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        paymentTokenAllowed[token] = allowed;
        emit PaymentTokenAllowedUpdated(token, allowed);
    }

    function listNFTWithPaymentToken(address nftContract, uint256 tokenId, address paymentToken, uint256 price)
        external
        nonReentrant
        returns (uint256)
    {
        _validateERC20OrderInput(nftContract, paymentToken, price);

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!_isApprovedForMarketplace(nft, msg.sender, tokenId)) revert MarketplaceNotApproved();

        erc20ListingCounter++;
        erc20Listings[erc20ListingCounter] = ERC20Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            price: price,
            active: true
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ERC20NFTListed(erc20ListingCounter, msg.sender, nftContract, tokenId, paymentToken, price);

        return erc20ListingCounter;
    }

    function buyNFTWithPaymentToken(uint256 listingId) external nonReentrant {
        ERC20Listing storage listing = erc20Listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (msg.sender == listing.seller) revert CannotBuyOwnNFT();

        listing.active = false;

        IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), listing.price);
        _payoutERC20Sale(listing.paymentToken, listing.nftContract, listing.tokenId, listing.seller, listing.price);
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit ERC20NFTSold(listingId, msg.sender, listing.seller, listing.paymentToken, listing.price);
    }

    function createAuctionWithPaymentToken(
        address nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 startPrice,
        uint256 durationHours
    ) external nonReentrant returns (uint256) {
        _validateERC20OrderInput(nftContract, paymentToken, startPrice);
        if (durationHours <= 1) revert InvalidDuration();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!_isApprovedForMarketplace(nft, msg.sender, tokenId)) revert MarketplaceNotApproved();

        erc20AuctionCounter++;
        uint256 endTime = block.timestamp + durationHours * 1 hours;
        erc20Auctions[erc20AuctionCounter] = ERC20Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            active: true
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ERC20AuctionCreated(
            erc20AuctionCounter, msg.sender, nftContract, tokenId, paymentToken, startPrice, endTime
        );

        return erc20AuctionCounter;
    }

    function placeERC20Bid(uint256 auctionId, uint256 bidAmount) external nonReentrant {
        ERC20Auction storage auction = erc20Auctions[auctionId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.endTime <= block.timestamp) revert AuctionEndedAlready();
        if (msg.sender == auction.seller) revert SellerCannotBid();

        uint256 minBid = auction.startPrice;
        if (auction.highestBid != 0) {
            minBid = auction.highestBid + (auction.highestBid * MIN_BID_INCREMENT_BPS / BASIS_POINTS);
        }

        if (bidAmount < minBid) revert BidTooLow();

        IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), bidAmount);

        if (auction.highestBidder != address(0)) {
            erc20PendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = bidAmount;
        auction.highestBidder = msg.sender;

        emit ERC20BidPlaced(auctionId, msg.sender, auction.paymentToken, bidAmount);
    }

    function endERC20Auction(uint256 auctionId) external nonReentrant {
        ERC20Auction storage auction = erc20Auctions[auctionId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.endTime > block.timestamp) revert AuctionNotEnded();

        auction.active = false;

        if (auction.highestBidder == address(0)) {
            IERC721(auction.nftContract).safeTransferFrom(address(this), auction.seller, auction.tokenId);
            emit ERC20AuctionEnded(auctionId, address(0), auction.paymentToken, 0);
            return;
        }

        uint256 highestBid = auction.highestBid;
        _payoutERC20Sale(auction.paymentToken, auction.nftContract, auction.tokenId, auction.seller, highestBid);
        IERC721(auction.nftContract).safeTransferFrom(address(this), auction.highestBidder, auction.tokenId);

        emit ERC20AuctionEnded(auctionId, auction.highestBidder, auction.paymentToken, highestBid);
    }

    function withdrawERC20Bid(uint256 auctionId) external nonReentrant {
        ERC20Auction memory auction = erc20Auctions[auctionId];
        uint256 amount = erc20PendingReturns[auctionId][msg.sender];
        if (amount == 0) revert NoPendingReturn();

        erc20PendingReturns[auctionId][msg.sender] = 0;
        IERC20(auction.paymentToken).safeTransfer(msg.sender, amount);

        emit ERC20BidWithdrawn(auctionId, msg.sender, auction.paymentToken, amount);
    }

    function _validateERC20OrderInput(address nftContract, address paymentToken, uint256 price) private view {
        if (nftContract == address(0) || paymentToken == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (!paymentTokenAllowed[paymentToken]) revert PaymentTokenNotAllowed();
    }

    function _payoutERC20Sale(
        address paymentToken,
        address nftContract,
        uint256 tokenId,
        address seller,
        uint256 salePrice
    ) internal {
        uint256 fee = salePrice * platformFee / BASIS_POINTS;
        (address receiver, uint256 royaltyAmount) = _getRoyaltyInfo(nftContract, tokenId, salePrice);
        if (fee + royaltyAmount > salePrice) revert InvalidRoyalty();

        uint256 sellerAmount = salePrice - fee - royaltyAmount;
        IERC20 token = IERC20(paymentToken);

        if (receiver != address(0) && royaltyAmount > 0) {
            token.safeTransfer(receiver, royaltyAmount);
        }

        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
        }

        token.safeTransfer(seller, sellerAmount);
    }

    uint256[50] private __gapV2;
}
