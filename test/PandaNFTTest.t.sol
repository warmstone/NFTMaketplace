// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {PandaNFT} from "../src/PandaNFT.sol";

contract PandaNFTTest is Test {
    PandaNFT public pandaNFT;

    address public owner = address(this);
    address public user = address(0x1);
    address public anotherUser = address(0x2);
    address public royaltyReceiver = address(0x3);

    string public constant TOKEN_URI = "ipfs://panda-token-uri";

    event NFTMinted(address indexed minter, uint256 indexed tokenId, string uri);

    receive() external payable {}

    function setUp() public {
        pandaNFT = new PandaNFT();

        vm.deal(user, 10 ether);
        vm.deal(anotherUser, 10 ether);
    }

    function testDeploymentInitializesMetadataOwnerPriceAndSupply() public view {
        assertEq(pandaNFT.name(), "PandaNFT");
        assertEq(pandaNFT.symbol(), "PNFT");
        assertEq(pandaNFT.owner(), owner);
        assertEq(pandaNFT.mintPrice(), 0.01 ether);
        assertEq(pandaNFT.totalSupply(), 0);
        assertEq(pandaNFT.MAX_SUPPLY(), 10_000);
    }

    function testMintCreatesTokenForSenderAndStoresURI() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        uint256 tokenId = pandaNFT.mint{value: mintPrice}(TOKEN_URI);

        assertEq(tokenId, 1);
        assertEq(pandaNFT.ownerOf(tokenId), user);
        assertEq(pandaNFT.balanceOf(user), 1);
        assertEq(pandaNFT.totalSupply(), 1);
        assertEq(pandaNFT.tokenURI(tokenId), TOKEN_URI);
        assertEq(address(pandaNFT).balance, mintPrice);
    }

    function testMintEmitsNFTMintedEvent() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.expectEmit(true, true, false, true);
        emit NFTMinted(user, 1, TOKEN_URI);

        vm.prank(user);
        pandaNFT.mint{value: mintPrice}(TOKEN_URI);
    }

    function testMintAllowsOverpayment() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        uint256 tokenId = pandaNFT.mint{value: mintPrice + 1 ether}(TOKEN_URI);

        assertEq(tokenId, 1);
        assertEq(pandaNFT.ownerOf(tokenId), user);
        assertEq(address(pandaNFT).balance, mintPrice + 1 ether);
    }

    function testMintRevertsWhenPaymentIsInsufficient() public {
        uint256 insufficientPayment = pandaNFT.mintPrice() - 1;

        vm.expectRevert(bytes("Insufficient payment"));

        vm.prank(user);
        pandaNFT.mint{value: insufficientPayment}(TOKEN_URI);
    }

    function testMultipleMintsIncrementTokenIdsAndSupply() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        uint256 firstTokenId = pandaNFT.mint{value: mintPrice}("ipfs://first");

        vm.prank(anotherUser);
        uint256 secondTokenId = pandaNFT.mint{value: mintPrice}("ipfs://second");

        assertEq(firstTokenId, 1);
        assertEq(secondTokenId, 2);
        assertEq(pandaNFT.ownerOf(firstTokenId), user);
        assertEq(pandaNFT.ownerOf(secondTokenId), anotherUser);
        assertEq(pandaNFT.totalSupply(), 2);
    }

    function testTokenURIRevertsForNonexistentToken() public {
        vm.expectRevert();

        pandaNFT.tokenURI(1);
    }

    function testOwnerCanSetMintPrice() public {
        uint256 newMintPrice = 0.05 ether;

        pandaNFT.setMintPrice(newMintPrice);

        assertEq(pandaNFT.mintPrice(), newMintPrice);
    }

    function testSetMintPriceRevertsForNonOwner() public {
        vm.expectRevert();

        vm.prank(user);
        pandaNFT.setMintPrice(0.05 ether);
    }

    function testSetMintPriceRevertsForZeroPrice() public {
        vm.expectRevert(bytes("MintPrice must great than 0"));

        pandaNFT.setMintPrice(0);
    }

    function testMintUsesUpdatedMintPrice() public {
        uint256 newMintPrice = 0.05 ether;
        pandaNFT.setMintPrice(newMintPrice);

        vm.expectRevert(bytes("Insufficient payment"));
        vm.prank(user);
        pandaNFT.mint{value: 0.01 ether}(TOKEN_URI);

        vm.prank(user);
        uint256 tokenId = pandaNFT.mint{value: newMintPrice}(TOKEN_URI);

        assertEq(tokenId, 1);
        assertEq(pandaNFT.ownerOf(tokenId), user);
    }

    function testOwnerCanWithdrawMintFees() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        pandaNFT.mint{value: mintPrice}(TOKEN_URI);

        uint256 ownerBalanceBefore = owner.balance;

        pandaNFT.withdraw();

        assertEq(address(pandaNFT).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + mintPrice);
    }

    function testWithdrawRevertsForNonOwner() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        pandaNFT.mint{value: mintPrice}(TOKEN_URI);

        vm.expectRevert();

        vm.prank(user);
        pandaNFT.withdraw();
    }

    function testWithdrawRevertsWhenContractHasNoBalance() public {
        vm.expectRevert(bytes("No balance to withdrwa"));

        pandaNFT.withdraw();
    }

    function testDefaultRoyaltyIsSetToOwnerAtTenPercent() public view {
        uint256 salePrice = 1 ether;

        (address receiver, uint256 royaltyAmount) = pandaNFT.royaltyInfo(1, salePrice);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0.1 ether);
    }

    function testOwnerCanSetDefaultRoyalty() public {
        pandaNFT.setDefaultRoyalty(royaltyReceiver, 500);

        (address receiver, uint256 royaltyAmount) = pandaNFT.royaltyInfo(1, 2 ether);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0.1 ether);
    }

    function testSetDefaultRoyaltyRevertsForNonOwner() public {
        vm.expectRevert();

        vm.prank(user);
        pandaNFT.setDefaultRoyalty(royaltyReceiver, 500);
    }

    function testOwnerCanSetTokenRoyalty() public {
        uint256 mintPrice = pandaNFT.mintPrice();

        vm.prank(user);
        uint256 tokenId = pandaNFT.mint{value: mintPrice}(TOKEN_URI);

        pandaNFT.setTokenRoyalty(tokenId, royaltyReceiver, 750);

        (address receiver, uint256 royaltyAmount) = pandaNFT.royaltyInfo(tokenId, 2 ether);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0.15 ether);
    }

    function testSupportsERC721MetadataAndERC2981Interfaces() public view {
        assertTrue(pandaNFT.supportsInterface(0x80ac58cd));
        assertTrue(pandaNFT.supportsInterface(0x5b5e139f));
        assertTrue(pandaNFT.supportsInterface(0x2a55205a));
    }
}
