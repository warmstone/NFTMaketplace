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
    /// @dev Tracks the most recently minted token id. Token ids start at 1.
    uint256 private _tokenIdCounter;

    /// @notice Maximum number of NFTs that can ever be minted.
    uint256 public constant MAX_SUPPLY = 10_000;
    /// @notice Price required to mint one PandaNFT.
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
        // Default royalty is 10% and can be updated by the contract owner.
        _setDefaultRoyalty(msg.sender, 1000);
    }

    /// @notice Mints a new NFT to the caller after receiving the exact mint price.
    /// @dev Minting is disabled while the contract is paused.
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

    /// @notice Returns the number of tokens minted so far.
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /// @notice Withdraws all mint proceeds to the current owner.
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalanceToWithdraw();

        address recipient = owner();
        (bool success,) = payable(recipient).call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit Withdrawn(recipient, balance);
    }

    /// @notice Updates the mint price for future mints.
    function setMintPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidMintPrice();

        uint256 oldPrice = mintPrice;
        mintPrice = newPrice;

        emit MintPriceUpdated(oldPrice, newPrice);
    }

    /// @notice Sets the default ERC2981 royalty for the whole collection.
    /// @param royalty Address that receives royalty payments.
    /// @param royaltyBps Royalty rate in basis points, where 10_000 is 100%.
    function setDefaultRoyalty(address royalty, uint96 royaltyBps) external onlyOwner {
        _setDefaultRoyalty(royalty, royaltyBps);

        emit DefaultRoyaltyUpdated(royalty, royaltyBps);
    }

    /// @notice Overrides the royalty receiver and rate for a single token.
    function setTokenRoyalty(uint256 tokenId, address royalty, uint96 royaltyBps) external onlyOwner {
        if (_ownerOf(tokenId) == address(0)) revert TokenDoesNotExist();

        _setTokenRoyalty(tokenId, royalty, royaltyBps);

        emit TokenRoyaltyUpdated(tokenId, royalty, royaltyBps);
    }

    /// @notice Pauses minting.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes minting.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Required because both ERC721 and ERC721URIStorage define tokenURI.
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @dev Includes ERC721, URI storage, and ERC2981 interface support.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
