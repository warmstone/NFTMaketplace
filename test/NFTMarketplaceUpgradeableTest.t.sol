// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PandaNFT} from "../src/PandaNFT.sol";
import {NFTMarketplaceUpgradeable} from "../src/upgradeable/NFTMarketplaceUpgradeable.sol";

contract NFTMarketplaceUpgradeableTest is Test {
    NFTMarketplaceUpgradeable public marketplace;
    NFTMarketplaceUpgradeable public implementation;
    PandaNFT public pandaNFT;
    ERC20Mock public paymentToken;

    address public owner = address(this);
    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public bidder = address(0x3);
    address public feeRecipient = address(0x4);

    string public constant TOKEN_URI = "ipfs://upgradeable-market-token";

    receive() external payable {}

    function setUp() public {
        implementation = new NFTMarketplaceUpgradeable();
        bytes memory initData = abi.encodeCall(NFTMarketplaceUpgradeable.initialize, (owner, feeRecipient));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        marketplace = NFTMarketplaceUpgradeable(address(proxy));

        pandaNFT = new PandaNFT();
        paymentToken = new ERC20Mock();

        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
        vm.deal(bidder, 10 ether);
    }

    function testProxyInitializesOwnerFeeRecipientAndDefaultFee() public view {
        assertEq(marketplace.owner(), owner);
        assertEq(marketplace.feeRecipient(), feeRecipient);
        assertEq(marketplace.platformFee(), 250);
        assertEq(marketplace.version(), "1.0.0");
    }

    function testImplementationCannotBeInitializedDirectly() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner, feeRecipient);
    }

    function testOwnerCanUpgradeAndKeepExistingState() public {
        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.prank(seller);
        uint256 listingId = marketplace.listNFT(address(pandaNFT), tokenId, address(0), 1 ether);

        NFTMarketplaceUpgradeable newImplementation = new NFTMarketplaceUpgradeable();
        marketplace.upgradeToAndCall(address(newImplementation), "");

        assertEq(marketplace.owner(), owner);
        assertEq(marketplace.feeRecipient(), feeRecipient);

        vm.prank(buyer);
        marketplace.buyNFT{value: 1 ether}(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
    }

    function testNonOwnerCannotUpgrade() public {
        NFTMarketplaceUpgradeable newImplementation = new NFTMarketplaceUpgradeable();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        marketplace.upgradeToAndCall(address(newImplementation), "");
    }

    function testERC20FixedPricePurchaseAndPayouts() public {
        marketplace.setPaymentTokenAllowed(address(paymentToken), true);

        uint256 tokenId = _mintAndApprove(address(marketplace), seller);
        uint256 price = 100 ether;

        vm.prank(seller);
        uint256 listingId = marketplace.listNFT(address(pandaNFT), tokenId, address(paymentToken), price);

        paymentToken.mint(buyer, price);

        vm.prank(buyer);
        paymentToken.approve(address(marketplace), price);

        vm.prank(buyer);
        marketplace.buyNFT(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(address(this)), 10 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 2.5 ether);
        assertEq(paymentToken.balanceOf(seller), 87.5 ether);
    }

    function testERC20AuctionBidWithdrawalAndSettlement() public {
        marketplace.setPaymentTokenAllowed(address(paymentToken), true);

        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.prank(seller);
        uint256 auctionId = marketplace.createAuction(address(pandaNFT), tokenId, address(paymentToken), 100 ether, 2);

        paymentToken.mint(buyer, 100 ether);
        paymentToken.mint(bidder, 105 ether);

        vm.prank(buyer);
        paymentToken.approve(address(marketplace), 100 ether);
        vm.prank(buyer);
        marketplace.placeBid(auctionId, 100 ether);

        vm.prank(bidder);
        paymentToken.approve(address(marketplace), 105 ether);
        vm.prank(bidder);
        marketplace.placeBid(auctionId, 105 ether);

        assertEq(marketplace.pendingReturns(auctionId, buyer), 100 ether);

        vm.prank(buyer);
        marketplace.withdrawBid(auctionId);

        assertEq(paymentToken.balanceOf(buyer), 100 ether);
        assertEq(marketplace.pendingReturns(auctionId, buyer), 0);

        vm.warp(block.timestamp + 2 hours + 1);
        marketplace.endAuction(auctionId);

        assertEq(pandaNFT.ownerOf(tokenId), bidder);
        assertEq(paymentToken.balanceOf(address(this)), 10.5 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 2.625 ether);
        assertEq(paymentToken.balanceOf(seller), 91.875 ether);
    }

    function testRejectsUnapprovedPaymentToken() public {
        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.expectRevert(NFTMarketplaceUpgradeable.PaymentTokenNotAllowed.selector);
        vm.prank(seller);
        marketplace.listNFT(address(pandaNFT), tokenId, address(paymentToken), 100 ether);
    }

    function testUsdPricedERC20PurchaseThroughChainlinkFeed() public {
        UpgradeableMockV3Aggregator feed = new UpgradeableMockV3Aggregator(8, 2_000e8);

        marketplace.setPaymentTokenAllowed(address(paymentToken), true);
        marketplace.setERC20PriceFeed(address(paymentToken), address(feed), 1 hours);

        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.prank(seller);
        uint256 listingId = marketplace.listNFTWithUsdPrice(address(pandaNFT), tokenId, address(paymentToken), 100e18);

        assertEq(marketplace.quoteListing(listingId), 0.05 ether);

        paymentToken.mint(buyer, 0.05 ether);

        vm.prank(buyer);
        paymentToken.approve(address(marketplace), 0.05 ether);

        vm.prank(buyer);
        marketplace.buyNFT(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(address(this)), 0.005 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 0.00125 ether);
        assertEq(paymentToken.balanceOf(seller), 0.04375 ether);
    }

    function testGettersExposeTokenAddressAndUsdFlag() public {
        marketplace.setPaymentTokenAllowed(address(paymentToken), true);
        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.prank(seller);
        uint256 listingId = marketplace.listNFT(address(pandaNFT), tokenId, address(paymentToken), 100 ether);

        (,, uint256 returnedTokenId, address tokenAddress, uint256 price, bool useUsdPrice, bool active) =
            marketplace.getListing(listingId);

        assertEq(returnedTokenId, tokenId);
        assertEq(tokenAddress, address(paymentToken));
        assertEq(price, 100 ether);
        assertFalse(useUsdPrice);
        assertTrue(active);
    }

    function _mintAndApprove(address operator, address tokenOwner) private returns (uint256 tokenId) {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(tokenOwner);
        tokenId = pandaNFT.mint{value: mintPrice}(TOKEN_URI);

        vm.prank(tokenOwner);
        pandaNFT.approve(operator, tokenId);
    }
}

contract UpgradeableMockV3Aggregator {
    uint8 public immutable decimals;
    int256 public answer;
    uint80 public roundId = 1;
    uint256 public updatedAt;

    constructor(uint8 feedDecimals, int256 initialAnswer) {
        decimals = feedDecimals;
        answer = initialAnswer;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 currentRoundId,
            int256 currentAnswer,
            uint256 startedAt,
            uint256 currentUpdatedAt,
            uint80 answeredInRound
        )
    {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}
