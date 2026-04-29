// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTMarketplaceUpgradeableV2} from "./NFTMarketplaceUpgradeableV2.sol";

interface IMarketplacePriceOracle {
    function quote(address token, uint256 usdAmount) external view returns (uint256 tokenAmount);
}

/// @notice V3 upgrade that adds USD-denominated ERC20 listings using a Chainlink-style oracle.
contract NFTMarketplaceUpgradeableV3 is NFTMarketplaceUpgradeableV2 {
    using SafeERC20 for IERC20;

    struct USDListing {
        address seller;
        address nftContract;
        uint256 tokenId;
        address paymentToken;
        uint256 usdPrice;
        bool active;
    }

    address public priceOracle;
    mapping(uint256 => USDListing) public usdListings;
    uint256 public usdListingCounter;

    error PriceOracleNotSet();

    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);
    event USDNFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        address paymentToken,
        uint256 usdPrice
    );
    event USDNFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address paymentToken,
        uint256 usdPrice,
        uint256 tokenAmount
    );

    function initializeV3(address initialPriceOracle) external reinitializer(2) {
        if (initialPriceOracle == address(0)) revert ZeroAddress();
        priceOracle = initialPriceOracle;
        emit PriceOracleUpdated(address(0), initialPriceOracle);
    }

    function version() external pure override returns (string memory) {
        return "3.0.0";
    }

    function setPriceOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert ZeroAddress();

        address oldOracle = priceOracle;
        priceOracle = newOracle;

        emit PriceOracleUpdated(oldOracle, newOracle);
    }

    function quoteUSDListing(uint256 listingId) external view returns (uint256 tokenAmount) {
        USDListing memory listing = usdListings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (priceOracle == address(0)) revert PriceOracleNotSet();

        return IMarketplacePriceOracle(priceOracle).quote(listing.paymentToken, listing.usdPrice);
    }

    function listNFTWithUsdPrice(address nftContract, uint256 tokenId, address paymentToken, uint256 usdPrice)
        external
        nonReentrant
        returns (uint256)
    {
        if (nftContract == address(0) || paymentToken == address(0)) revert ZeroAddress();
        if (usdPrice == 0) revert InvalidPrice();
        if (!paymentTokenAllowed[paymentToken]) revert PaymentTokenNotAllowed();

        IERC721 nft = IERC721(nftContract);
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (!_isApprovedForMarketplace(nft, msg.sender, tokenId)) revert MarketplaceNotApproved();

        usdListingCounter++;
        usdListings[usdListingCounter] = USDListing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            usdPrice: usdPrice,
            active: true
        });

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit USDNFTListed(usdListingCounter, msg.sender, nftContract, tokenId, paymentToken, usdPrice);

        return usdListingCounter;
    }

    function buyNFTWithUsdPrice(uint256 listingId) external nonReentrant {
        USDListing storage listing = usdListings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (msg.sender == listing.seller) revert CannotBuyOwnNFT();
        if (priceOracle == address(0)) revert PriceOracleNotSet();

        uint256 tokenAmount = IMarketplacePriceOracle(priceOracle).quote(listing.paymentToken, listing.usdPrice);
        listing.active = false;

        IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), tokenAmount);
        _payoutERC20Sale(listing.paymentToken, listing.nftContract, listing.tokenId, listing.seller, tokenAmount);
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId);

        emit USDNFTSold(listingId, msg.sender, listing.seller, listing.paymentToken, listing.usdPrice, tokenAmount);
    }

    uint256[50] private __gapV3;
}
