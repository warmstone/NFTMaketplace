// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title PandaNFT
 * @author warmstone
 * @notice Mintable ERC721 collection with ERC2981 royalty support.
 */
contract PandaNFT is ERC721, ERC721URIStorage, ERC2981, Ownable, Pausable {
    uint256 private _tokenIdCounter;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public mintPrice = 0.01 ether;

    error MaxSupplyReached();
    error IncorrectPayment();
    error EmptyTokenURI();
    error InvalidMintPrice();
    error NoBalanceToWithdraw();
    error WithdrawFailed();
    error TokenDoesNotExist();

    event NFTMinted(address indexed minter, uint256 indexed tokenId, string uri);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event Withdrawn(address indexed recipient, uint256 amount);
    event DefaultRoyaltyUpdated(address indexed receiver, uint96 royaltyBps);
    event TokenRoyaltyUpdated(uint256 indexed tokenId, address indexed receiver, uint96 royaltyBps);

    constructor() ERC721("PandaNFT", "PNFT") Ownable(msg.sender) {
        _setDefaultRoyalty(msg.sender, 1000);
    }

    function mint(string calldata uri) external payable whenNotPaused returns (uint256) {
        if (_tokenIdCounter >= MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value != mintPrice) revert IncorrectPayment();
        if (bytes(uri).length == 0) revert EmptyTokenURI();

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, uri);

        emit NFTMinted(msg.sender, newTokenId, uri);

        return newTokenId;
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalanceToWithdraw();

        address recipient = owner();
        (bool success,) = payable(recipient).call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit Withdrawn(recipient, balance);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidMintPrice();

        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;

        emit MintPriceUpdated(oldPrice, newPrice);
    }

    function setDefaultRoyalty(address royalty, uint96 royaltyBps) external onlyOwner {
        _setDefaultRoyalty(royalty, royaltyBps);

        emit DefaultRoyaltyUpdated(royalty, royaltyBps);
    }

    function setTokenRoyalty(uint256 tokenId, address royalty, uint96 royaltyBps) external onlyOwner {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _setTokenRoyalty(tokenId, royalty, royaltyBps);

        emit TokenRoyaltyUpdated(tokenId, royalty, royaltyBps);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
