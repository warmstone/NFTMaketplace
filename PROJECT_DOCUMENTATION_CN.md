# NFTMarketplace 中文项目文档

## 1. 项目结构

```text
NFTMarketplace/
|-- script/
|   |-- DeployPandaNFT.s.sol
|   |-- DeployNFTMarketplace.s.sol
|   |-- DeployNFTMarketplaceUpgradeable.s.sol
|   |-- DeployChainlinkPriceOracle.s.sol
|   |-- UpgradeNFTMarketplaceToV2.s.sol
|   `-- UpgradeNFTMarketplaceToV3.s.sol
|-- src/
|   |-- PandaNFT.sol
|   |-- NFTMarketplace.sol
|   |-- oracle/
|   |   |-- AggregatorV3Interface.sol
|   |   `-- ChainlinkPriceOracle.sol
|   `-- upgradeable/
|       |-- NFTMarketplaceUpgradeable.sol
|       |-- NFTMarketplaceUpgradeableV2.sol
|       `-- NFTMarketplaceUpgradeableV3.sol
|-- test/
|   |-- PandaNFTTest.t.sol
|   |-- NFTMarketplaceTest.t.sol
|   |-- NFTMarketplaceUpgradeableTest.t.sol
|   `-- ChainlinkPriceOracleTest.t.sol
|-- lib/
|   |-- forge-std/
|   |-- openzeppelin-contracts/
|   `-- openzeppelin-contracts-upgradeable/
|-- foundry.toml
|-- remappings.txt
|-- foundry.lock
|-- TEST_REPORT.md
`-- README.md
```

主要目录说明：

- `src/`：核心 Solidity 合约。
- `src/oracle/`：Chainlink 风格价格预言机模块。
- `src/upgradeable/`：UUPS 可升级市场合约。
- `script/`：部署和升级脚本。
- `test/`：Foundry 测试文件。
- `lib/`：Foundry 依赖库，包括 OpenZeppelin 普通合约和可升级合约。

## 2. 功能说明

### 2.1 `PandaNFT`

`PandaNFT` 是一个 ERC721 NFT 合约，支持付费铸造和 ERC2981 版税。

主要功能：

- NFT 名称：`PandaNFT`
- NFT 符号：`PNFT`
- 最大供应量：`10_000`
- 默认铸造价格：`0.01 ether`
- 支持 `tokenURI`
- 支持 ERC2981 版税
- 默认版税为 10%
- owner 可以修改铸造价格
- owner 可以设置默认版税和单个 token 版税
- owner 可以暂停和恢复铸造
- owner 可以提取铸造收入

主要函数：

- `mint(string calldata uri)`：支付铸造价格并铸造 NFT。
- `totalSupply()`：查询已铸造数量。
- `withdraw()`：owner 提取合约 ETH。
- `setMintPrice(uint256 newPrice)`：修改铸造价格。
- `setDefaultRoyalty(address royalty, uint96 royaltyBps)`：设置默认版税。
- `setTokenRoyalty(uint256 tokenId, address royalty, uint96 royaltyBps)`：设置单个 token 版税。
- `pause()` / `unpause()`：暂停或恢复铸造。

### 2.2 `NFTMarketplace`

`NFTMarketplace` 是原始 NFT 市场合约，使用原生 ETH 作为支付资产。

主要功能：

- 固定价格挂单
- 取消挂单
- 修改挂单价格
- 使用 ETH 购买 NFT
- 创建 ETH 拍卖
- ETH 出价
- 被超过出价后的退款提现
- 拍卖结束结算
- 平台手续费
- ERC2981 版税结算
- NFT 托管
- 重入保护

主要函数：

- `listNFT(address nftContract, uint256 tokenId, uint256 price)`：上架 NFT。
- `delistNFT(uint256 listingId)`：取消上架。
- `updatePrice(uint256 listingId, uint256 newPrice)`：修改挂单价格。
- `buyNFT(uint256 listingId)`：使用 ETH 购买 NFT。
- `createAuction(address nftContract, uint256 tokenId, uint256 startPrice, uint256 durationHours)`：创建拍卖。
- `placeBid(uint256 auctionId)`：ETH 出价。
- `withdrawBid(uint256 auctionId)`：提取被超过的出价。
- `endAuction(uint256 auctionId)`：结束拍卖并结算。
- `setPlatformFee(uint256 newFee)`：修改平台手续费。
- `updateFeeRecipient(address newRecipient)`：修改手续费接收地址。

### 2.3 `NFTMarketplaceUpgradeable`

`NFTMarketplaceUpgradeable` 是 UUPS 可升级市场的基础版本，保留 ETH 挂单、ETH 购买、ETH 拍卖和版税结算功能。

主要特点：

- 使用 OpenZeppelin `UUPSUpgradeable`
- 使用 OpenZeppelin `OwnableUpgradeable`
- 通过 `initialize(address initialOwner, address initialFeeRecipient)` 初始化
- owner 控制合约升级权限
- 支持原生 ETH 市场功能

### 2.4 `NFTMarketplaceUpgradeableV2`

`NFTMarketplaceUpgradeableV2` 在 UUPS 市场基础上增加 ERC20 支付能力。

主要功能：

- 设置允许使用的 ERC20 支付 Token
- ERC20 固定价格挂单
- ERC20 购买 NFT
- ERC20 拍卖
- ERC20 出价
- ERC20 退款提现
- ERC20 成交后的版税、平台费和卖家收益分账

主要函数：

- `setPaymentTokenAllowed(address token, bool allowed)`：设置 ERC20 支付 Token 白名单。
- `listNFTWithPaymentToken(address nftContract, uint256 tokenId, address paymentToken, uint256 price)`：使用 ERC20 计价上架 NFT。
- `buyNFTWithPaymentToken(uint256 listingId)`：使用 ERC20 购买 NFT。
- `createAuctionWithPaymentToken(...)`：创建 ERC20 拍卖。
- `placeERC20Bid(uint256 auctionId, uint256 bidAmount)`：ERC20 出价。
- `withdrawERC20Bid(uint256 auctionId)`：提取 ERC20 退款。
- `endERC20Auction(uint256 auctionId)`：结束 ERC20 拍卖。

### 2.5 `ChainlinkPriceOracle`

`ChainlinkPriceOracle` 是价格预言机模块，用于根据 Chainlink 风格的价格源把 18 位 USD 金额换算为指定 Token 数量。

主要功能：

- 为原生 ETH 或 ERC20 Token 配置价格源
- 支持 ERC20 decimals 自动读取
- 检查价格是否有效
- 检查价格是否过期
- 返回 USD 金额对应的 Token 支付数量

主要函数：

- `setFeed(address token, address feed, uint8 tokenDecimals, uint256 maxStaleness)`：配置价格源。
- `setERC20Feed(address token, address feed, uint256 maxStaleness)`：为 ERC20 配置价格源。
- `disableFeed(address token)`：禁用价格源。
- `quote(address token, uint256 usdAmount)`：将 USD 金额换算成 Token 数量。

### 2.6 `NFTMarketplaceUpgradeableV3`

`NFTMarketplaceUpgradeableV3` 在 V2 基础上接入价格预言机，支持 USD 计价的 ERC20 购买。

主要功能：

- 设置市场使用的价格预言机
- USD 价格上架 NFT
- 查询 USD 挂单当前需要支付的 ERC20 数量
- 使用 ERC20 按预言机报价购买 NFT

主要函数：

- `initializeV3(address initialPriceOracle)`：初始化 V3 预言机地址。
- `setPriceOracle(address newOracle)`：修改价格预言机。
- `listNFTWithUsdPrice(address nftContract, uint256 tokenId, address paymentToken, uint256 usdPrice)`：按 USD 计价上架 NFT。
- `quoteUSDListing(uint256 listingId)`：查询当前 ERC20 支付数量。
- `buyNFTWithUsdPrice(uint256 listingId)`：按预言机报价使用 ERC20 购买 NFT。

## 3. 部署步骤

### 3.1 准备环境变量

在项目根目录创建 `.env`：

```bash
PRIVATE_KEY=你的部署钱包私钥
RPC_URL=你的 RPC 地址
# FEE_RECIPIENT=平台手续费接收地址
# ORACLE_OWNER=预言机 owner 地址
# MARKETPLACE_PROXY=UUPS 代理合约地址
# PRICE_ORACLE=ChainlinkPriceOracle 合约地址
```

说明：

- `PRIVATE_KEY`：必填，用于广播部署或升级交易。
- `RPC_URL`：必填，目标网络 RPC。
- `FEE_RECIPIENT`：可选，不设置时部署脚本默认使用部署者地址。
- `ORACLE_OWNER`：可选，不设置时预言机 owner 默认为部署者地址。
- `MARKETPLACE_PROXY`：执行升级脚本时必填。
- `PRICE_ORACLE`：升级到 V3 时必填。

加载环境变量：

```bash
source .env
```

### 3.2 编译和测试

部署前建议先执行：

```bash
forge build
forge test -vvv
```

### 3.3 部署 `PandaNFT`

```bash
forge script script/DeployPandaNFT.s.sol:DeployPandaNFT \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### 3.4 部署原始 `NFTMarketplace`

```bash
forge script script/DeployNFTMarketplace.s.sol:DeployNFTMarketplace \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### 3.5 部署 UUPS 可升级市场

```bash
forge script script/DeployNFTMarketplaceUpgradeable.s.sol:DeployNFTMarketplaceUpgradeable \
  --rpc-url "$RPC_URL" \
  --broadcast
```

部署完成后记录代理合约地址，并写入 `.env`：

```bash
MARKETPLACE_PROXY=0xYourMarketplaceProxyAddress
```

### 3.6 升级 UUPS 市场到 V2

V2 增加 ERC20 支付和出价功能。

```bash
forge script script/UpgradeNFTMarketplaceToV2.s.sol:UpgradeNFTMarketplaceToV2 \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### 3.7 部署 `ChainlinkPriceOracle`

```bash
forge script script/DeployChainlinkPriceOracle.s.sol:DeployChainlinkPriceOracle \
  --rpc-url "$RPC_URL" \
  --broadcast
```

部署完成后记录预言机地址，并写入 `.env`：

```bash
PRICE_ORACLE=0xYourPriceOracleAddress
```

### 3.8 升级 UUPS 市场到 V3

V3 增加基于预言机的 USD 计价 ERC20 购买功能。

```bash
forge script script/UpgradeNFTMarketplaceToV3.s.sol:UpgradeNFTMarketplaceToV3 \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### 3.9 配置 ERC20 支付 Token

升级到 V2 或 V3 后，需要先允许某个 ERC20 Token 作为支付资产：

```solidity
setPaymentTokenAllowed(tokenAddress, true)
```

### 3.10 配置价格源

使用 V3 前，需要在 `ChainlinkPriceOracle` 中配置对应 Token 的 Chainlink Price Feed：

```solidity
setERC20Feed(tokenAddress, feedAddress, maxStaleness)
```

其中：

- `tokenAddress`：支付 ERC20 Token 地址。
- `feedAddress`：Chainlink Price Feed 地址。
- `maxStaleness`：价格最大允许过期时间，例如 `3600` 表示 1 小时。
