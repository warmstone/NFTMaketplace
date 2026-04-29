// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PandaNFT} from "../src/PandaNFT.sol";
import {ChainlinkPriceOracle} from "../src/oracle/ChainlinkPriceOracle.sol";
import {NFTMarketplaceUpgradeable} from "../src/upgradeable/NFTMarketplaceUpgradeable.sol";
import {NFTMarketplaceUpgradeableV2} from "../src/upgradeable/NFTMarketplaceUpgradeableV2.sol";
import {NFTMarketplaceUpgradeableV3} from "../src/upgradeable/NFTMarketplaceUpgradeableV3.sol";

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
    }

    function testImplementationCannotBeInitializedDirectly() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(owner, feeRecipient);
    }

    function testOwnerCanUpgradeToV2AndKeepExistingState() public {
        uint256 tokenId = _mintAndApprove(address(marketplace), seller);

        vm.prank(seller);
        uint256 listingId = marketplace.listNFT(address(pandaNFT), tokenId, 1 ether);

        NFTMarketplaceUpgradeableV2 v2Implementation = new NFTMarketplaceUpgradeableV2();
        marketplace.upgradeToAndCall(address(v2Implementation), "");

        NFTMarketplaceUpgradeableV2 upgraded = NFTMarketplaceUpgradeableV2(address(marketplace));

        assertEq(upgraded.version(), "2.0.0");
        assertEq(upgraded.owner(), owner);
        assertEq(upgraded.feeRecipient(), feeRecipient);

        vm.prank(buyer);
        upgraded.buyNFT{value: 1 ether}(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
    }

    function testNonOwnerCannotUpgrade() public {
        NFTMarketplaceUpgradeableV2 v2Implementation = new NFTMarketplaceUpgradeableV2();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, buyer));
        vm.prank(buyer);
        marketplace.upgradeToAndCall(address(v2Implementation), "");
    }

    function testV2SupportsERC20FixedPricePurchaseAndPayouts() public {
        NFTMarketplaceUpgradeableV2 upgraded = _upgradeToV2();
        upgraded.setPaymentTokenAllowed(address(paymentToken), true);

        uint256 tokenId = _mintAndApprove(address(upgraded), seller);
        uint256 price = 100 ether;

        vm.prank(seller);
        uint256 listingId = upgraded.listNFTWithPaymentToken(address(pandaNFT), tokenId, address(paymentToken), price);

        paymentToken.mint(buyer, price);

        vm.prank(buyer);
        paymentToken.approve(address(upgraded), price);

        vm.prank(buyer);
        upgraded.buyNFTWithPaymentToken(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(address(this)), 10 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 2.5 ether);
        assertEq(paymentToken.balanceOf(seller), 87.5 ether);
    }

    function testV2SupportsERC20AuctionBidWithdrawalAndSettlement() public {
        NFTMarketplaceUpgradeableV2 upgraded = _upgradeToV2();
        upgraded.setPaymentTokenAllowed(address(paymentToken), true);

        uint256 tokenId = _mintAndApprove(address(upgraded), seller);

        vm.prank(seller);
        uint256 auctionId =
            upgraded.createAuctionWithPaymentToken(address(pandaNFT), tokenId, address(paymentToken), 100 ether, 2);

        paymentToken.mint(buyer, 100 ether);
        paymentToken.mint(bidder, 105 ether);

        vm.prank(buyer);
        paymentToken.approve(address(upgraded), 100 ether);
        vm.prank(buyer);
        upgraded.placeERC20Bid(auctionId, 100 ether);

        vm.prank(bidder);
        paymentToken.approve(address(upgraded), 105 ether);
        vm.prank(bidder);
        upgraded.placeERC20Bid(auctionId, 105 ether);

        assertEq(upgraded.erc20PendingReturns(auctionId, buyer), 100 ether);

        vm.prank(buyer);
        upgraded.withdrawERC20Bid(auctionId);

        assertEq(paymentToken.balanceOf(buyer), 100 ether);
        assertEq(upgraded.erc20PendingReturns(auctionId, buyer), 0);

        vm.warp(block.timestamp + 2 hours + 1);
        upgraded.endERC20Auction(auctionId);

        assertEq(pandaNFT.ownerOf(tokenId), bidder);
        assertEq(paymentToken.balanceOf(address(this)), 10.5 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 2.625 ether);
        assertEq(paymentToken.balanceOf(seller), 91.875 ether);
    }

    function testV2RejectsUnapprovedPaymentToken() public {
        NFTMarketplaceUpgradeableV2 upgraded = _upgradeToV2();
        uint256 tokenId = _mintAndApprove(address(upgraded), seller);

        vm.expectRevert(NFTMarketplaceUpgradeableV2.PaymentTokenNotAllowed.selector);
        vm.prank(seller);
        upgraded.listNFTWithPaymentToken(address(pandaNFT), tokenId, address(paymentToken), 100 ether);
    }

    function testV3SupportsUsdPricedERC20PurchaseThroughOracle() public {
        UpgradeableMockV3Aggregator feed = new UpgradeableMockV3Aggregator(8, 2_000e8);
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(owner);
        oracle.setERC20Feed(address(paymentToken), address(feed), 1 hours);

        NFTMarketplaceUpgradeableV3 upgraded = _upgradeToV3(address(oracle));
        upgraded.setPaymentTokenAllowed(address(paymentToken), true);

        uint256 tokenId = _mintAndApprove(address(upgraded), seller);

        vm.prank(seller);
        uint256 listingId = upgraded.listNFTWithUsdPrice(address(pandaNFT), tokenId, address(paymentToken), 100e18);

        assertEq(upgraded.quoteUSDListing(listingId), 0.05 ether);

        paymentToken.mint(buyer, 0.05 ether);

        vm.prank(buyer);
        paymentToken.approve(address(upgraded), 0.05 ether);

        vm.prank(buyer);
        upgraded.buyNFTWithUsdPrice(listingId);

        assertEq(pandaNFT.ownerOf(tokenId), buyer);
        assertEq(paymentToken.balanceOf(address(this)), 0.005 ether);
        assertEq(paymentToken.balanceOf(feeRecipient), 0.00125 ether);
        assertEq(paymentToken.balanceOf(seller), 0.04375 ether);
    }

    function _upgradeToV2() private returns (NFTMarketplaceUpgradeableV2 upgraded) {
        NFTMarketplaceUpgradeableV2 v2Implementation = new NFTMarketplaceUpgradeableV2();
        marketplace.upgradeToAndCall(address(v2Implementation), "");
        upgraded = NFTMarketplaceUpgradeableV2(address(marketplace));
    }

    function _upgradeToV3(address oracle) private returns (NFTMarketplaceUpgradeableV3 upgraded) {
        NFTMarketplaceUpgradeableV3 v3Implementation = new NFTMarketplaceUpgradeableV3();
        bytes memory initData = abi.encodeCall(NFTMarketplaceUpgradeableV3.initializeV3, (oracle));
        marketplace.upgradeToAndCall(address(v3Implementation), initData);
        upgraded = NFTMarketplaceUpgradeableV3(address(marketplace));
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
