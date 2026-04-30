# NFTMarketplace 中文项目文档

## 项目概览

这是一个基于 Foundry 的 NFT 市场项目，包含：

- `PandaNFT`：支持付费铸造、暂停、提现和 ERC2981 版税的 ERC721 NFT。
- `NFTMarketplace`：原始 ETH 版市场合约，保留固定价格购买、拍卖、平台费和版税结算。
- `NFTMarketplaceUpgradeable`：UUPS 可升级市场第一版，已经内置 ETH/ERC20 支付、ERC20 出价和 Chainlink 价格源报价。

## 目录结构

```text
NFTMarketplace/
|-- src/
|   |-- PandaNFT.sol
|   |-- NFTMarketplace.sol
|   `-- upgradeable/
|       `-- NFTMarketplaceUpgradeable.sol
|-- test/
|   |-- PandaNFTTest.t.sol
|   |-- NFTMarketplaceTest.t.sol
|   `-- NFTMarketplaceUpgradeableTest.t.sol
|-- script/
|   |-- DeployPandaNFT.s.sol
|   |-- DeployNFTMarketplace.s.sol
|   `-- DeployNFTMarketplaceUpgradeable.s.sol
|-- foundry.toml
|-- remappings.txt
`-- README.md
```

## 核心功能

### PandaNFT

- `mint(string calldata uri)`：支付铸造价格并铸造 NFT。
- `setMintPrice(uint256 newPrice)`：owner 修改铸造价格。
- `setDefaultRoyalty(address royalty, uint96 royaltyBps)`：设置默认版税。
- `setTokenRoyalty(uint256 tokenId, address royalty, uint96 royaltyBps)`：设置单个 NFT 版税。
- `pause()` / `unpause()`：暂停或恢复铸造。
- `withdraw()`：owner 提取铸造收入。

### NFTMarketplaceUpgradeable

- `initialize(address initialOwner, address initialFeeRecipient)`：初始化 UUPS 代理状态。
- `listNFT(address nftContract, uint256 tokenId, address tokenAddress, uint256 price)`：使用 ETH 或 ERC20 上架，`tokenAddress` 为 0 地址时表示 ETH。
- `listNFTWithUsdPrice(address nftContract, uint256 tokenId, address tokenAddress, uint256 usdPrice)`：使用 USD 计价上架，购买时通过 Chainlink feed 折算 ERC20 支付数量。
- `buyNFT(uint256 listingId)`：购买挂单；ETH 挂单需要精确 `msg.value`，ERC20 挂单需要提前 `approve`。
- `createAuction(address nftContract, uint256 tokenId, address tokenAddress, uint256 startPrice, uint256 durationHours)`：创建 ETH 或 ERC20 拍卖。
- `placeBid(uint256 auctionId, uint256 bidAmount)`：出价；ETH 拍卖需要同时发送等额 `msg.value`，ERC20 拍卖需要提前 `approve`。
- `withdrawBid(uint256 auctionId)`：被超越出价后提取退款，退款资产由该拍卖的 `tokenAddress` 决定。
- `endAuction(uint256 auctionId)`：结束拍卖并结算 NFT、平台费、版税和卖家收入。
- `setPaymentTokenAllowed(address tokenAddress, bool allowed)`：owner 设置 ERC20 支付白名单。
- `setPriceFeed(address tokenAddress, address feed, uint8 tokenDecimals, uint256 maxStaleness)`：owner 配置 Chainlink 价格源。
- `setERC20PriceFeed(address tokenAddress, address feed, uint256 maxStaleness)`：owner 为 ERC20 自动读取 decimals 并配置价格源。
- `quoteListing(uint256 listingId)`：查询 USD 挂单当前需要支付的 Token 数量。
- `quoteTokenAmount(address tokenAddress, uint256 usdAmount)`：按 Chainlink feed 将 18 位 USD 金额换算为 Token 数量。

## Chainlink 价格源说明

项目不再部署自定义预言机合约。升级版市场直接保存并读取 Chainlink `AggregatorV3Interface`：

1. owner 调用 `setERC20PriceFeed(token, feed, maxStaleness)`。
2. 合约读取 `latestRoundData()` 和 `decimals()`。
3. 合约检查价格必须大于 0、轮次必须有效、更新时间不能超过 `maxStaleness`。
4. USD 挂单购买时使用当前报价折算 ERC20 数量。

`usdPrice` 使用 18 位精度，例如 100 美元写作 `100e18`。

## 部署

准备 `.env`：

```bash
PRIVATE_KEY=你的部署钱包私钥
SEPOLIA_RPC=你的 Sepolia RPC
MAINNET_RPC=你的 Mainnet RPC
# FEE_RECIPIENT=平台手续费接收地址，未设置时默认为部署者
```

编译和测试：

```bash
forge build
forge test -vvv
```

部署 `PandaNFT`：

```bash
forge script script/DeployPandaNFT.s.sol:DeployPandaNFT \
  --rpc-url "$SEPOLIA_RPC" \
  --broadcast
```

部署原始 ETH 市场：

```bash
forge script script/DeployNFTMarketplace.s.sol:DeployNFTMarketplace \
  --rpc-url "$SEPOLIA_RPC" \
  --broadcast
```

部署 UUPS 可升级市场：

```bash
forge script script/DeployNFTMarketplaceUpgradeable.s.sol:DeployNFTMarketplaceUpgradeable \
  --rpc-url "$SEPOLIA_RPC" \
  --broadcast
```

## 测试覆盖

当前测试覆盖：

- `PandaNFT` 铸造、版税、暂停、提现和权限控制。
- 原始 ETH 市场的上架、购买、拍卖、退款、平台费和版税。
- UUPS 初始化、升级权限、状态保持。
- 升级版市场第一版中的 ERC20 固定价购买、ERC20 拍卖出价/退款/结算。
- Chainlink feed 报价下的 USD 计价 ERC20 购买。

运行结果应为全部测试通过。
