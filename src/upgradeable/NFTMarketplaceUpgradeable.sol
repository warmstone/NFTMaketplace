// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice UUPS upgradeable NFT marketplace supporting ETH, ERC20, and Chainlink USD quotes in the first version.
contract NFTMarketplaceUpgradeable is OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address tokenAddress;
        uint256 price;
        bool useUsdPrice;
        bool active;
    }

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        address tokenAddress;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool active;
    }

    struct PriceFeedConfig {
        AggregatorV3Interface feed;
        uint8 tokenDecimals;
        uint256 maxStaleness;
        bool active;
    }

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_PLATFORM_FEE = 1_000;
    uint256 public constant MIN_BID_INCREMENT_BPS = 500;

    mapping(uint256 => Listing) public listings;
    uint256 public listingCounter;

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    mapping(address => bool) public paymentTokenAllowed;
    mapping(address => PriceFeedConfig) public priceFeeds;

    address public feeRecipient;
    uint256 public platformFee;

    error ZeroAddress();
    error InvalidPrice();
    error InvalidDuration();
    error NotOwner();
    error NotSeller();
    error NotFeeRecipient();
    error MarketplaceNotApproved();
    error ListingNotActive();
    error AuctionNotActive();
    error AuctionEndedAlready();
    error AuctionNotEnded();
    error SellerCannotBid();
    error CannotBuyOwnNFT();
    error IncorrectPayment();
    error BidTooLow();
    error NoPendingReturn();
    error FeeTooHigh();
    error InvalidRoyalty();
    error TransferFailed();
    error PaymentTokenNotAllowed();
    error NativeTokenNotAllowed();
    error PriceFeedNotActive();
    error InvalidOraclePrice();
    error StaleOraclePrice();

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        bool useUsdPrice
    );
    event NFTDelisted(uint256 indexed listingId);
    event NFTPriceUpdated(uint256 indexed listingId, uint256 oldPrice, uint256 newPrice);
    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address tokenAddress,
        uint256 price,
        uint256 paidAmount
    );
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address tokenAddress,
        uint256 startPrice,
        uint256 endTime
    );
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, address indexed tokenAddress, uint256 bidAmount);
    event AuctionEnded(uint256 indexed auctionId, address indexed buyer, address indexed tokenAddress, uint256 price);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, address indexed tokenAddress, uint256 amount);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event PaymentTokenAllowedUpdated(address indexed tokenAddress, bool allowed);
    event PriceFeedConfigured(
        address indexed tokenAddress, address indexed feed, uint8 tokenDecimals, uint256 maxStaleness
    );
    event PriceFeedDisabled(address indexed tokenAddress);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address initialFeeRecipient) external initializer {
        if (initialOwner == address(0) || initialFeeRecipient == address(0)) revert ZeroAddress();

        __Ownable_init(initialOwner);
        feeRecipient = initialFeeRecipient;
        platformFee = 250;
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @notice Fixed-price listing paid with ETH when tokenAddress is zero, otherwise with an allowed ERC20 token.
    function listNFT(address nftContract, uint256 tokenId, address tokenAddress, uint256 price)
        external
        nonReentrant
        returns (uint256)
    {
        return _listNFT(nftContract, tokenId, tokenAddress, price, false);
    }

    /// @notice Stores a USD-denominated listing and converts it through the configured Chainlink feed at purchase time.
    function listNFTWithUsdPrice(address nftContract, uint256 tokenId, address tokenAddress, uint256 usdPrice)
        external
        nonReentrant
        returns (uint256)
    {
        if (tokenAddress == address(0)) revert NativeTokenNotAllowed();
        _requireActivePriceFeed(tokenAddress);
        return _listNFT(nftContract, tokenId, tokenAddress, usdPrice, true);
    }

    function delistNFT(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        listing.active = false;
        IERC721(listing.nftContract).safeTransferFrom(address(this), listing.seller, listing.tokenId);

        emit NFTDelisted(listingId);
    }

    function updatePrice(uint256 listingId, uint256 newPrice) external {
        if (newPrice == 0) revert InvalidPrice();

        Listing storage listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (listing.seller != msg.sender) revert NotSeller();

        uint256 oldPrice = listing.price;
        listing.price = newPrice;

        emit NFTPriceUpdated(listingId, oldPrice, newPrice);
    }

    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];

        if (!listing.active) revert ListingNotActive();
        if (msg.sender == listing.seller) revert CannotBuyOwnNFT();

        uint256 paymentAmount = listing.useUsdPrice ? quoteListing(listingId) : listing.price;
        listing.active = false;

        _collectPayment(listing.tokenAddress, paymentAmount);
        _payoutSale(listing.tokenAddress, listing.nftContract, listing.tokenId, listing.seller, paymentAmount);
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit NFTSold(listingId, msg.sender, listing.seller, listing.tokenAddress, listing.price, paymentAmount);
    }

    function createAuction(
        address nftContract,
        uint256 tokenId,
        address tokenAddress,
        uint256 startPrice,
        uint256 durationHours
    ) external nonReentrant returns (uint256) {
        return _createAuction(nftContract, tokenId, tokenAddress, startPrice, durationHours);
    }

    function placeBid(uint256 auctionId, uint256 bidAmount) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        if (auction.tokenAddress == address(0)) {
            if (msg.value != bidAmount) revert IncorrectPayment();
        } else {
            if (msg.value != 0) revert IncorrectPayment();
            IERC20(auction.tokenAddress).safeTransferFrom(msg.sender, address(this), bidAmount);
        }
        _placeBid(auctionId, bidAmount);
    }

    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.endTime > block.timestamp) revert AuctionNotEnded();

        auction.active = false;

        if (auction.highestBidder == address(0)) {
            IERC721(auction.nftContract).safeTransferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionEnded(auctionId, address(0), auction.tokenAddress, 0);
            return;
        }

        uint256 highestBid = auction.highestBid;
        _payoutSale(auction.tokenAddress, auction.nftContract, auction.tokenId, auction.seller, highestBid);
        IERC721(auction.nftContract).safeTransferFrom(address(this), auction.highestBidder, auction.tokenId);

        emit AuctionEnded(auctionId, auction.highestBidder, auction.tokenAddress, highestBid);
    }

    function withdrawBid(uint256 auctionId) external nonReentrant {
        Auction memory auction = auctions[auctionId];
        uint256 amount = pendingReturns[auctionId][msg.sender];
        if (amount == 0) revert NoPendingReturn();

        pendingReturns[auctionId][msg.sender] = 0;
        _sendPayment(auction.tokenAddress, msg.sender, amount);

        emit BidWithdrawn(auctionId, msg.sender, auction.tokenAddress, amount);
    }

    function getListing(uint256 listingId)
        external
        view
        returns (
            address seller,
            address nftContract,
            uint256 tokenId,
            address tokenAddress,
            uint256 price,
            bool useUsdPrice,
            bool active
        )
    {
        Listing memory listing = listings[listingId];
        return (
            listing.seller,
            listing.nftContract,
            listing.tokenId,
            listing.tokenAddress,
            listing.price,
            listing.useUsdPrice,
            listing.active
        );
    }

    function getAuction(uint256 auctionId)
        external
        view
        returns (
            address seller,
            address nftContract,
            uint256 tokenId,
            address tokenAddress,
            uint256 startPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 endTime,
            bool active
        )
    {
        Auction memory auction = auctions[auctionId];
        return (
            auction.seller,
            auction.nftContract,
            auction.tokenId,
            auction.tokenAddress,
            auction.startPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.endTime,
            auction.active
        );
    }

    function setPaymentTokenAllowed(address tokenAddress, bool allowed) external onlyOwner {
        if (tokenAddress == address(0)) revert ZeroAddress();
        paymentTokenAllowed[tokenAddress] = allowed;
        emit PaymentTokenAllowedUpdated(tokenAddress, allowed);
    }

    function setPriceFeed(address tokenAddress, address feed, uint8 tokenDecimals, uint256 maxStaleness)
        external
        onlyOwner
    {
        if (feed == address(0)) revert ZeroAddress();

        priceFeeds[tokenAddress] = PriceFeedConfig({
            feed: AggregatorV3Interface(feed), tokenDecimals: tokenDecimals, maxStaleness: maxStaleness, active: true
        });

        emit PriceFeedConfigured(tokenAddress, feed, tokenDecimals, maxStaleness);
    }

    function setERC20PriceFeed(address tokenAddress, address feed, uint256 maxStaleness) external onlyOwner {
        if (tokenAddress == address(0) || feed == address(0)) revert ZeroAddress();

        uint8 tokenDecimals = IERC20Metadata(tokenAddress).decimals();
        priceFeeds[tokenAddress] = PriceFeedConfig({
            feed: AggregatorV3Interface(feed), tokenDecimals: tokenDecimals, maxStaleness: maxStaleness, active: true
        });

        emit PriceFeedConfigured(tokenAddress, feed, tokenDecimals, maxStaleness);
    }

    function disablePriceFeed(address tokenAddress) external onlyOwner {
        priceFeeds[tokenAddress].active = false;
        emit PriceFeedDisabled(tokenAddress);
    }

    function quoteListing(uint256 listingId) public view returns (uint256 tokenAmount) {
        Listing memory listing = listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (!listing.useUsdPrice) return listing.price;

        return quoteTokenAmount(listing.tokenAddress, listing.price);
    }

    /// @notice Converts an 18-decimal USD amount into the configured token amount by reading Chainlink latestRoundData.
    function quoteTokenAmount(address tokenAddress, uint256 usdAmount) public view returns (uint256 tokenAmount) {
        PriceFeedConfig memory config = priceFeeds[tokenAddress];
        if (!config.active) revert PriceFeedNotActive();

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = config.feed.latestRoundData();
        if (answer <= 0 || answeredInRound < roundId) revert InvalidOraclePrice();
        if (config.maxStaleness != 0 && block.timestamp - updatedAt > config.maxStaleness) revert StaleOraclePrice();

        uint8 feedDecimals = config.feed.decimals();
        return usdAmount * (10 ** feedDecimals) * (10 ** config.tokenDecimals) / uint256(answer) / 1e18;
    }

    function setPlatformFee(uint256 newFee) external {
        if (msg.sender != feeRecipient) revert NotFeeRecipient();
        if (newFee > MAX_PLATFORM_FEE) revert FeeTooHigh();

        uint256 oldFee = platformFee;
        platformFee = newFee;

        emit PlatformFeeUpdated(oldFee, newFee);
    }

    function updateFeeRecipient(address newRecipient) external {
        if (msg.sender != feeRecipient) revert NotFeeRecipient();
        if (newRecipient == address(0)) revert ZeroAddress();

        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _listNFT(address nftContract, uint256 tokenId, address tokenAddress, uint256 price, bool useUsdPrice)
        private
        returns (uint256)
    {
        _validateOrderInput(nftContract, tokenAddress, price);

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!_isApprovedForMarketplace(nft, msg.sender, tokenId)) revert MarketplaceNotApproved();

        listingCounter++;
        listings[listingCounter] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            price: price,
            useUsdPrice: useUsdPrice,
            active: true
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit NFTListed(listingCounter, msg.sender, nftContract, tokenId, tokenAddress, price, useUsdPrice);

        return listingCounter;
    }

    function _createAuction(
        address nftContract,
        uint256 tokenId,
        address tokenAddress,
        uint256 startPrice,
        uint256 durationHours
    ) private returns (uint256) {
        _validateOrderInput(nftContract, tokenAddress, startPrice);
        if (durationHours <= 1) revert InvalidDuration();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!_isApprovedForMarketplace(nft, msg.sender, tokenId)) revert MarketplaceNotApproved();

        auctionCounter++;
        uint256 endTime = block.timestamp + durationHours * 1 hours;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            active: true
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(auctionCounter, msg.sender, nftContract, tokenId, tokenAddress, startPrice, endTime);

        return auctionCounter;
    }

    function _placeBid(uint256 auctionId, uint256 bidAmount) private {
        Auction storage auction = auctions[auctionId];
        if (!auction.active) revert AuctionNotActive();
        if (auction.endTime <= block.timestamp) revert AuctionEndedAlready();
        if (msg.sender == auction.seller) revert SellerCannotBid();

        uint256 minBid = auction.startPrice;
        if (auction.highestBid != 0) {
            // Keep every new bid at least 5% higher, so auctions cannot be extended by dust-size increases.
            minBid = auction.highestBid + (auction.highestBid * MIN_BID_INCREMENT_BPS / BASIS_POINTS);
        }

        if (bidAmount < minBid) revert BidTooLow();

        if (auction.highestBidder != address(0)) {
            // Pull refunds avoid making an external call to the previous bidder during the new bid transaction.
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = bidAmount;
        auction.highestBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, auction.tokenAddress, bidAmount);
    }

    function _validateOrderInput(address nftContract, address tokenAddress, uint256 price) private view {
        if (nftContract == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (tokenAddress != address(0) && !paymentTokenAllowed[tokenAddress]) revert PaymentTokenNotAllowed();
    }

    function _requireActivePriceFeed(address tokenAddress) private view {
        if (!priceFeeds[tokenAddress].active) revert PriceFeedNotActive();
    }

    function _collectPayment(address tokenAddress, uint256 amount) private {
        if (tokenAddress == address(0)) {
            if (msg.value != amount) revert IncorrectPayment();
        } else {
            if (msg.value != 0) revert IncorrectPayment();
            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _payoutSale(address tokenAddress, address nftContract, uint256 tokenId, address seller, uint256 salePrice)
        internal
    {
        uint256 fee = salePrice * platformFee / BASIS_POINTS;
        (address receiver, uint256 royaltyAmount) = _getRoyaltyInfo(nftContract, tokenId, salePrice);
        if (fee + royaltyAmount > salePrice) revert InvalidRoyalty();

        uint256 sellerAmount = salePrice - fee - royaltyAmount;

        if (receiver != address(0) && royaltyAmount > 0) {
            _sendPayment(tokenAddress, receiver, royaltyAmount);
        }

        if (fee > 0) {
            _sendPayment(tokenAddress, feeRecipient, fee);
        }

        _sendPayment(tokenAddress, seller, sellerAmount);
    }

    function _getRoyaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        try IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId) returns (bool supportsRoyalty) {
            if (!supportsRoyalty) return (address(0), 0);
        } catch {
            return (address(0), 0);
        }

        try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (address royaltyReceiver, uint256 amount) {
            return (royaltyReceiver, amount);
        } catch {
            return (address(0), 0);
        }
    }

    function _isApprovedForMarketplace(IERC721 nft, address tokenOwner, uint256 tokenId) internal view returns (bool) {
        return nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(tokenOwner, address(this));
    }

    function _sendPayment(address tokenAddress, address recipient, uint256 amount) private {
        if (tokenAddress == address(0)) {
            _sendValue(recipient, amount);
        } else {
            IERC20(tokenAddress).safeTransfer(recipient, amount);
        }
    }

    function _sendValue(address recipient, uint256 amount) internal {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    uint256[45] private __gap;
}
