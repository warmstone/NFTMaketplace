pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract NFTMarketplace is ReentrancyGuard {
    // NFT上架结构体
    struct Listing {
        // 卖家
        address seller;
        // NFT 地址
        address nftContract;
        // tokenId
        uint256 tokenId;
        // 价格
        uint256 price;
        // 是否上架
        bool active;
    }

    // 拍卖结构体
    struct Auction {
        // 卖家
        address seller;
        // NFT 地址
        address nftContract;
        // tokenId
        uint256 tokenId;
        // 起拍价
        uint256 startPrice;
        // 当前最高价
        uint256 highestBid;
        // 最高出价者的地址
        address highestBidder;
        // 拍卖结束时间
        uint256 endTime;
        // 拍卖是否激活
        bool active;
    }

    // 挂单映射
    mapping(uint256 => Listing) public listings;
    // 挂单计数器
    uint256 public listingCounter;

    // 拍卖映射
    mapping(uint256 => Auction) public auctions;
    // 拍卖计数器
    uint256 auctionCounter;

    // 待退款映射
    mapping(uint256 => mapping(address => uint256)) pendingReturns;

    // 平台手续费
    address public feeRecipient;
    uint256 public platformFee = 250;

    // NFT上架事件
    event NFTListed(
        uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price
    );

    // NFT下架事件
    event NFTDelisted(uint256 indexed listingId);

    // 修改价格事件
    event NFTPriceUpdated(uint256 indexed listingId, uint256 newPrice);

    // 购买事件
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, uint256 price);

    // 创建拍卖事件
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endTime
    );

    // 出价事件
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 bidAmount);

    // 拍卖结束事件
    event AuctionEnded(uint256 indexed auctionId, address indexed buyer, uint256 price);

    // 构造器，初始化手续费接收地址
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "FeeRecipient cannot be zero address");
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev 上架NFT
     * @param nftContract NTF合约地址
     * @param tokenId tokenId
     * @param price 价格
     */
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external returns (uint256) {
        // 地址检查
        require(nftContract != address(0), "NFT contract address can not be zero address");
        require(price > 0, "Price must be greater then 0");

        // 检查NFT所有者
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");

        // 检查授权
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        // 上架
        listingCounter++;
        listings[listingCounter] =
            Listing({seller: msg.sender, nftContract: nftContract, tokenId: tokenId, price: price, active: true});

        emit NFTListed(listingCounter, msg.sender, nftContract, tokenId, price);

        return listingCounter;
    }

    /**
     * @dev 下架NFT
     * @param listingId 挂单Id
     */
    function delistNFT(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing is not active");
        // 只有卖家可以下架自己的NFT
        require(listing.seller == msg.sender, "Not the owner");

        listing.active = false;

        emit NFTDelisted(listingId);
    }

    /**
     * @dev 修改NTF价格
     * @param listingId 挂单Id
     * @param newPrice NFT新价格
     */
    function updatePrice(uint256 listingId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than 0");

        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not the owner");

        listing.price = newPrice;

        emit NFTPriceUpdated(listingId, newPrice);
    }

    /**
     * @dev 购买NFT
     * @param listingId 挂单Id
     */
    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];

        // Checks
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");
        require(msg.sender != listing.seller, "Cannot buy your own NFT");

        // Effects
        listing.active = false;

        // Interactions
        // 资金分配：版税>手续费>卖家收益
        (address receiver, uint256 royaltyAmount) = _getRoyaltyInfo(listing.nftContract, listing.tokenId, listing.price);

        // 手续费
        uint256 fee = listing.price * platformFee / 10000;

        // 卖家收益
        uint256 sellerAmount = listing.price - fee - royaltyAmount;

        // 转移所有权
        IERC721 nft = IERC721(listing.nftContract);
        nft.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // 转账
        if (receiver != address(0) && royaltyAmount > 0) {
            (bool successRoyalty,) = receiver.call{value: royaltyAmount}("");
            require(successRoyalty, "Transfer royalty failed");
        }

        (bool successSeller,) = listing.seller.call{value: sellerAmount}("");
        require(successSeller, "Transfer to seller failed");

        (bool successFee,) = feeRecipient.call{value: fee}("");
        require(successFee, "Transfer fee failed");

        // 退还剩余资金
        if (msg.value > listing.price) {
            (bool refundSuccess,) = msg.sender.call{value: msg.value - listing.price}("");
            require(refundSuccess, "Refund failed");
        }

        emit NFTSold(listingId, msg.sender, listing.seller, listing.price);
    }

    /**
     * @dev 创建拍卖
     * @param nftContract NFT 合约地址
     * @param tokenId tokenId
     * @param startPrice 起拍价
     * @param durationHours 拍卖持续小时数
     */
    function createAuction(address nftContract, uint256 tokenId, uint256 startPrice, uint256 durationHours)
        external
        returns (uint256)
    {
        require(nftContract != address(0), "NFT contract address cannot be zero address");
        require(startPrice > 0, "Start price must be greater than 0");
        require(durationHours > 1, "Duration hours must be greater than 1");

        IERC721 nft = IERC721(nftContract);
        // NFT的 onwer 才可以创建拍卖
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        auctionCounter++;
        auctions[auctionCounter] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + durationHours * 1 hours,
            active: true
        });

        emit AuctionCreated(
            auctionCounter, msg.sender, nftContract, tokenId, startPrice, block.timestamp + durationHours * 1 hours
        );

        return auctionCounter;
    }

    /**
     * @dev 出价
     * @param auctionId 拍卖Id
     */
    function placeBid(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(auction.endTime > block.timestamp, "Auction ended");
        require(msg.sender != auction.seller, "Seller cannot bid");

        uint256 minBid = 0;
        if (auction.highestBid == 0) {
            minBid = auction.startPrice;
        } else {
            minBid = auction.highestBid + (auction.highestBid * 5 / 100);
        }

        require(msg.value >= minBid, "Bid too low");

        if (auction.highestBidder != address(0)) {
            // 之前有人出价，需要放到待退款
            pendingReturns[auctionId][auction.highestBidder] += auction.highestBid;
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    /**
     * @dev 结束拍卖
     * @param auctionId 拍卖Id
     */
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(auction.endTime < block.timestamp, "Auction not ended");
        require(msg.sender == auction.seller, "Not the seller");

        auction.active = false;

        if (auction.highestBidder == address(0)) {
            // 流拍
            emit AuctionEnded(auctionId, address(0), 0);
            return;
        }

        // 计算费用
        uint256 highestBid = auction.highestBid;
        address nftContract = auction.nftContract;

        // 手续费
        uint256 fee = highestBid * (platformFee / 10000);

        // 版税
        (address receiver, uint256 royaltyAmount) = _getRoyaltyInfo(nftContract, auction.tokenId, highestBid);

        // 卖家所得
        uint256 sellerAmount = highestBid - fee - royaltyAmount;

        // 转移NFT所有权
        IERC721(nftContract).safeTransferFrom(auction.seller, auction.highestBidder, auction.tokenId);

        // 资金分配:版税>手续费>卖家所得
        if (receiver != address(0) && royaltyAmount > 0) {
            // 版税
            (bool royaltySuccess,) = receiver.call{value: royaltyAmount}("");
            require(royaltySuccess, "Transfer royalty failed");
        }

        // 手续费
        (bool feeSuccess,) = feeRecipient.call{value: fee}("");
        require(feeSuccess, "Transfer fee failed");

        // 卖家所得
        (bool sellerSuccess,) = auction.seller.call{value: sellerAmount}("");
        require(sellerSuccess, "Transfer sellerAmount failed");

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid);
    }

    /**
     * @dev 提取出价
     * @param auctionId 拍卖Id
     */
    function withdrawBid(uint256 auctionId) external nonReentrant {
        uint256 amount = pendingReturns[auctionId][msg.sender];
        require(amount > 0, "No pending return");

        pendingReturns[auctionId][msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");

        require(success, "Trasfer failed");
    }

    /**
     * @dev 获取版税信息
     * @param nftContract NFT合约地址
     * @param tokenId tokenId
     * @param salePrice 售价
     * @return receiver 版税接收地址
     * @return royaltyAmount 版税
     */
    function _getRoyaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        private
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        if (IERC165(nftContract).supportsInterface(type(IERC2981).interfaceId)) {
            (receiver, royaltyAmount) = IERC2981(nftContract).royaltyInfo(tokenId, salePrice);
        } else {
            receiver = address(0);
            royaltyAmount = 0;
        }
    }

    /**
     * @dev 获取挂单信息
     * @param listingId 挂单Id
     * @return seller 卖家
     * @return nftContract NFT 合约地址
     * @return tokenId tokenId
     * @return price NFT价格
     * @return active 是否有效
     */
    function getListing(uint256 listingId)
        external
        view
        returns (address seller, address nftContract, uint256 tokenId, uint256 price, bool active)
    {
        Listing memory listing = listings[listingId];
        return (listing.seller, listing.nftContract, listing.tokenId, listing.price, listing.active);
    }

    /**
     * @dev 获取拍卖信息
     * @param auctionId 拍卖Id
     * @return seller 卖家
     * @return nftContract NFT 合约地址
     * @return tokenId tokenId
     * @return startPrice 起拍价
     * @return highestBid 最高出价
     * @return highestBidder 最高出价者
     * @return endTime 结束时间
     * @return active 是否有效
     */
    function getAuction(uint256 auctionId)
        external
        view
        returns (
            address seller,
            address nftContract,
            uint256 tokenId,
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
            auction.startPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.endTime,
            auction.active
        );
    }

    /**
     * @dev 设置新的手续费比例
     * @param newFee 手续费比例
     * @notice 只有手续费的接收地址可以调用
     */
    function setPlatformFee(uint256 newFee) external {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newFee <= 1000, "Fee too high");

        platformFee = newFee;
    }

    /**
     * @dev 设置新的手续费接收地址
     * @param newRecipient 手续费接收地址
     * @notice 只有手续费的接收地址可以调用
     */
    function updateFeeRecipient(address newRecipient) external {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newRecipient != address(0), "Invalid address");

        feeRecipient = newRecipient;
    }
}
