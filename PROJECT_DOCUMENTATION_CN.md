# NFTMarketplace 中文项目文档

本文件与 `README.md` 保持一致，项目主文档现在已经由中文内容替代默认 Foundry README。

## 当前合约结构

- `src/PandaNFT.sol`：ERC721 NFT，支持付费铸造、ERC2981 版税、暂停和提现。
- `src/NFTMarketplace.sol`：原始 ETH 市场合约。
- `src/upgradeable/NFTMarketplaceUpgradeable.sol`：UUPS 可升级市场第一版，内置 ETH/ERC20 支付、ERC20 出价和 Chainlink 价格源报价。
- `lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol`：Chainlink 官方 feed 接口，用于直接读取外部价格源。

## 支付资产约定

升级版市场在 `Listing` 和 `Auction` 中使用 `tokenAddress` 字段区分支付资产：

- `address(0)`：原生 ETH。
- 非 0 地址：ERC20 Token，必须先通过 `setPaymentTokenAllowed` 加入白名单。

## 预言机约定

项目已经删除自定义预言机合约，不再单独部署 oracle。`NFTMarketplaceUpgradeable` 直接配置并读取 Chainlink `AggregatorV3Interface`：

- `setPriceFeed(address tokenAddress, address feed, uint8 tokenDecimals, uint256 maxStaleness)`
- `setERC20PriceFeed(address tokenAddress, address feed, uint256 maxStaleness)`
- `quoteTokenAmount(address tokenAddress, uint256 usdAmount)`
- `quoteListing(uint256 listingId)`

USD 金额使用 18 位精度，例如 `100e18` 表示 100 美元。

## 常用命令

```bash
forge build
forge test -vvv
forge fmt
```

部署 UUPS 市场：

```bash
forge script script/DeployNFTMarketplaceUpgradeable.s.sol:DeployNFTMarketplaceUpgradeable \
  --rpc-url "$SEPOLIA_RPC" \
  --broadcast
```
