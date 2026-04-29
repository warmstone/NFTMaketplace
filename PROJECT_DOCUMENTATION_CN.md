# NFTMarketplace 项目文档

## 1. 项目概述

本项目是一个基于 Foundry 的 NFT 铸造与交易市场示例，包含两个核心合约：

- `PandaNFT`：支持付费铸造、URI 存储、暂停铸造、提现和 ERC2981 版税的 ERC721 NFT 合约。
- `NFTMarketplace`：支持固定价格挂单、拍卖、NFT 托管、平台手续费、ERC2981 版税结算和竞拍退款的 NFT 市场合约。

项目使用 OpenZeppelin 合约库作为基础能力，包括 ERC721、ERC721URIStorage、ERC2981、Ownable、Pausable、ReentrancyGuard 和 IERC721Receiver。

## 2. 项目结构

```text
NFTMarketplace/
├── .github/
│   └── workflows/
│       └── test.yml                  # GitHub Actions 测试流程
├── .vscode/                          # VS Code 配置
├── script/
│   ├── DeployNFTMarketplace.s.sol    # NFTMarketplace 部署脚本
│   └── DeployPandaNFT.s.sol          # PandaNFT 部署脚本
├── src/
│   ├── NFTMarketplace.sol            # NFT 市场合约
│   └── PandaNFT.sol                  # NFT 铸造合约
├── test/
│   ├── NFTMarketplaceTest.t.sol      # 市场合约测试
│   └── PandaNFTTest.t.sol            # NFT 合约测试
├── foundry.toml                      # Foundry 配置
├── foundry.lock                      # 依赖锁定文件
├── remappings.txt                    # Solidity import 路径映射
├── TEST_REPORT.md                    # 测试报告
└── README.md                         # Foundry 默认说明
```

说明：

- `.env` 用于保存本地部署环境变量，已经被 `.gitignore` 忽略，不应提交真实私钥。
- `lib/`、`cache/`、`out/` 是 Foundry 依赖、缓存和编译产物目录，未在上方展开。

## 3. 核心功能说明

### 3.1 `PandaNFT`

`PandaNFT` 是一个可铸造的 ERC721 NFT 合约，主要功能如下：

- NFT 名称：`PandaNFT`
- NFT 符号：`PNFT`
- 最大供应量：`10_000`
- 默认铸造价格：`0.01 ether`
- Token ID 从 `1` 开始递增
- 支持 `tokenURI` 存储
- 支持 ERC2981 版税
- 默认版税为 10%，接收者为部署者
- 合约 owner 可以修改铸造价格
- 合约 owner 可以设置默认版税和单个 token 的版税
- 合约 owner 可以暂停和恢复铸造
- 合约 owner 可以提取铸造收入

关键函数：

- `mint(string calldata uri)`：用户支付精确铸造价格后铸造 NFT。
- `totalSupply()`：返回已铸造数量。
- `withdraw()`：owner 提取合约内 ETH。
- `setMintPrice(uint256 newPrice)`：owner 修改铸造价格。
- `setDefaultRoyalty(address royalty, uint96 royaltyBps)`：owner 设置全局默认版税。
- `setTokenRoyalty(uint256 tokenId, address royalty, uint96 royaltyBps)`：owner 设置单个 NFT 的版税。
- `pause()` / `unpause()`：owner 暂停或恢复铸造。

### 3.2 `NFTMarketplace`

`NFTMarketplace` 是一个托管式 NFT 市场合约。卖家上架或创建拍卖时，NFT 会先转入市场合约托管，购买或拍卖结束后再转给买家或退回卖家。

主要功能如下：

- 支持固定价格挂单
- 支持取消挂单
- 支持修改挂单价格
- 支持使用原生 ETH 购买 NFT
- 支持创建拍卖
- 支持竞拍出价
- 支持被超过出价后的退款提现
- 支持拍卖结束后结算
- 支持平台手续费
- 支持 ERC2981 版税结算
- 使用 `ReentrancyGuard` 防止重入攻击
- 实现 `IERC721Receiver`，可以安全接收 ERC721 NFT

关键参数：

- `BASIS_POINTS = 10_000`：基点分母，表示 100%。
- `platformFee = 250`：默认平台手续费 2.5%。
- `MAX_PLATFORM_FEE = 1_000`：平台手续费最高 10%。
- `MIN_BID_INCREMENT_BPS = 500`：竞拍加价幅度最低 5%。

关键函数：

- `listNFT(address nftContract, uint256 tokenId, uint256 price)`：创建固定价格挂单并托管 NFT。
- `delistNFT(uint256 listingId)`：卖家取消挂单，NFT 退回卖家。
- `updatePrice(uint256 listingId, uint256 newPrice)`：卖家修改挂单价格。
- `buyNFT(uint256 listingId)`：买家支付精确 ETH 购买 NFT。
- `createAuction(address nftContract, uint256 tokenId, uint256 startPrice, uint256 durationHours)`：创建拍卖并托管 NFT。
- `placeBid(uint256 auctionId)`：对拍卖出价。
- `endAuction(uint256 auctionId)`：拍卖结束后结算。
- `withdrawBid(uint256 auctionId)`：被超过出价的用户提取退款。
- `setPlatformFee(uint256 newFee)`：当前手续费接收地址修改平台费。
- `updateFeeRecipient(address newRecipient)`：当前手续费接收地址转移手续费管理权和收款权。

### 3.3 资金流说明

固定价格购买和拍卖结算都通过 `_payoutSale()` 统一分账：

1. 计算平台手续费。
2. 如果 NFT 合约支持 ERC2981，则读取版税接收者和版税金额。
3. 检查平台手续费和版税总额不能超过成交价。
4. 支付版税。
5. 支付平台手续费。
6. 剩余金额支付给卖家。

拍卖退款使用 pull payment 模式：

- 新最高出价出现时，旧最高出价不会立即转回旧出价者。
- 旧出价金额会记录到 `pendingReturns[auctionId][bidder]`。
- 旧出价者主动调用 `withdrawBid()` 提现。

这种设计可以避免竞拍流程被旧出价者的 fallback 或 receive 函数阻塞。

## 4. 本地开发

### 4.1 安装依赖

项目使用 Foundry。安装 Foundry 后，在项目根目录执行：

```bash
forge install
```

如果依赖已经存在，可以直接编译和测试。

### 4.2 编译

```bash
forge build
```

### 4.3 格式化

```bash
forge fmt
```

### 4.4 测试

```bash
forge test -vvv
```

当前测试结果见 `TEST_REPORT.md`。最近一次测试结果：

```text
37 tests passed, 0 failed, 0 skipped
```

## 5. 环境变量

部署脚本通过 Foundry `forge-std/Script.sol` 提供的 `vm` cheatcode 读取环境变量。

推荐在项目根目录创建 `.env`：

```bash
PRIVATE_KEY=你的部署钱包私钥
RPC_URL=你的 RPC 地址
# FEE_RECIPIENT=平台手续费接收地址
```

变量说明：

- `PRIVATE_KEY`：必填，部署交易使用的私钥。
- `RPC_URL`：部署时传给 `forge script` 的 RPC 地址。
- `FEE_RECIPIENT`：部署 `NFTMarketplace` 时可选的环境变量。

注意：

- 对 `NFTMarketplace` 合约本身来说，构造函数参数 `_feeRecipient` 必填且不能是零地址。
- 对部署脚本来说，`FEE_RECIPIENT` 环境变量可以不设置；如果不设置，脚本会默认使用部署者地址。
- 不建议在 `.env` 中写空的 `FEE_RECIPIENT=`，因为空字符串可能导致地址解析失败。若不用自定义手续费接收地址，可以直接注释掉或删除该行。
- `.env` 已被 `.gitignore` 忽略，不要提交真实私钥。

## 6. 部署步骤

### 6.1 部署 `PandaNFT`

```bash
source .env

forge script script/DeployPandaNFT.s.sol:DeployPandaNFT \
  --rpc-url "$RPC_URL" \
  --broadcast
```

部署成功后，记录输出中的 `PandaNFT` 合约地址。

### 6.2 部署 `NFTMarketplace`

如果使用部署者地址作为手续费接收地址：

```bash
source .env

forge script script/DeployNFTMarketplace.s.sol:DeployNFTMarketplace \
  --rpc-url "$RPC_URL" \
  --broadcast
```

如果使用指定地址作为手续费接收地址：

```bash
source .env
export FEE_RECIPIENT=0xYourFeeRecipientAddress

forge script script/DeployNFTMarketplace.s.sol:DeployNFTMarketplace \
  --rpc-url "$RPC_URL" \
  --broadcast
```

### 6.3 常见部署检查

部署前建议确认：

- `PRIVATE_KEY` 对应的钱包有足够原生代币支付 gas。
- `RPC_URL` 指向正确网络。
- `FEE_RECIPIENT` 如果设置，必须是非零地址。
- 部署前执行 `forge test -vvv`，确保测试全部通过。

## 7. 基本使用流程

### 7.1 铸造 NFT

1. 调用 `PandaNFT.mint(uri)`。
2. `msg.value` 必须等于当前 `mintPrice`。
3. 铸造成功后，用户获得新的 NFT。

### 7.2 固定价格出售

1. NFT 持有人调用 `approve(marketplace, tokenId)` 或 `setApprovalForAll(marketplace, true)`。
2. 调用 `NFTMarketplace.listNFT(nftContract, tokenId, price)`。
3. NFT 转入市场合约托管。
4. 买家调用 `buyNFT(listingId)` 并支付精确价格。
5. 市场合约分配版税、平台手续费和卖家收益。
6. NFT 转给买家。

### 7.3 拍卖

1. NFT 持有人授权市场合约转移 NFT。
2. 调用 `createAuction(nftContract, tokenId, startPrice, durationHours)`。
3. NFT 转入市场合约托管。
4. 用户调用 `placeBid(auctionId)` 出价。
5. 被超过出价的用户调用 `withdrawBid(auctionId)` 提现。
6. 拍卖结束后，任何人都可以调用 `endAuction(auctionId)` 结算。

## 8. 后续功能改造规划

以下改造建议通过新增合约完成，不直接修改当前已经存在的 `PandaNFT.sol` 和 `NFTMarketplace.sol`。

### 8.1 支持 ERC20 购买和出价

目标：

- 在现有 ETH 支付模式之外，支持指定 ERC20 Token 作为购买和竞拍支付资产。
- 允许市场配置白名单 ERC20，例如 USDC、WETH 或项目自定义 Token。

建议新增合约：

- `NFTMarketplaceERC20.sol`
- 或 `NFTMarketplaceV2.sol`

核心设计：

- Listing 增加支付币种字段：

```solidity
address paymentToken;
```

- `paymentToken == address(0)` 可以表示原生 ETH。
- `paymentToken != address(0)` 表示使用 ERC20。
- ERC20 购买时，买家需要先调用 ERC20 的 `approve(marketplace, amount)`。
- 市场合约通过 `SafeERC20.safeTransferFrom()` 收款。
- 分账时使用 `SafeERC20.safeTransfer()` 支付版税、平台手续费和卖家收益。
- 拍卖出价时，建议将 ERC20 从出价者转入市场合约托管，避免结算时余额或授权不足。

需要新增或调整的数据结构：

```solidity
struct ListingV2 {
    address seller;
    address nftContract;
    uint256 tokenId;
    address paymentToken;
    uint256 price;
    bool active;
}

struct AuctionV2 {
    address seller;
    address nftContract;
    uint256 tokenId;
    address paymentToken;
    uint256 startPrice;
    uint256 highestBid;
    address highestBidder;
    uint256 endTime;
    bool active;
}
```

测试重点：

- ETH 购买仍然可用。
- ERC20 购买需要正确扣款和分账。
- ERC20 授权不足时应 revert。
- ERC20 拍卖出价、退款、结算金额正确。
- 不同 ERC20 之间不能混用出价。
- fee、royalty、seller proceeds 的 ERC20 转账正确。

### 8.2 集成 Chainlink 预言机

目标：

- 使用 Chainlink Price Feed 获取价格数据。
- 支持按美元或其他法币单位定价，再换算为 ETH 或 ERC20 支付金额。
- 为后续多币种支付提供可靠价格来源。

建议新增合约或模块：

- `PriceOracle.sol`
- `ChainlinkPriceOracle.sol`
- `NFTMarketplaceWithOracle.sol`

核心设计：

- 通过 Chainlink `AggregatorV3Interface` 读取价格。
- 为每个支付资产配置对应的 price feed。
- 读取价格时校验：
  - `answer > 0`
  - `updatedAt` 未过期
  - round 数据有效
- 增加最大过期时间，例如 `maxStaleness`。
- 对不同 decimals 的价格和 token 进行统一换算。

示例接口：

```solidity
interface IPriceOracle {
    function quote(address paymentToken, uint256 usdAmount) external view returns (uint256 tokenAmount);
}
```

使用场景：

- 卖家以 USD 计价 NFT，例如 `100e8` 表示 100 美元。
- 购买时，市场根据 Chainlink 价格计算需要支付的 ETH 或 ERC20 数量。
- 拍卖起拍价和出价也可以使用 USD 计价。

风险和注意点：

- Chainlink price feed 并非所有网络和资产都有。
- 不同 feed decimals 不同，需要严谨处理精度。
- 必须处理价格过期问题。
- 如果使用 L2，还需要关注 sequencer uptime feed。

测试重点：

- mock price feed 正常报价。
- 价格为 0 或负数时 revert。
- 价格过期时 revert。
- 不同 decimals 的换算正确。
- USD 价格换算后的购买和出价金额正确。

### 8.3 使用 OpenZeppelin UUPS 实现合约升级

目标：

- 使用 OpenZeppelin 的 UUPS 代理模式实现可升级市场合约。
- 不修改当前 `PandaNFT.sol` 和 `NFTMarketplace.sol`。
- 新增一套可升级合约，例如 `NFTMarketplaceUpgradeable.sol`。

建议新增文件：

```text
src/upgradeable/
├── NFTMarketplaceUpgradeable.sol
├── NFTMarketplaceUpgradeableV2.sol
└── interfaces/
    └── IMarketplaceVersion.sol

script/
├── DeployNFTMarketplaceUpgradeable.s.sol
└── UpgradeNFTMarketplace.s.sol

test/
└── NFTMarketplaceUpgradeableTest.t.sol
```

推荐继承 OpenZeppelin Upgradeable 合约：

- `Initializable`
- `UUPSUpgradeable`
- `OwnableUpgradeable`
- `ReentrancyGuardUpgradeable`
- `IERC721Receiver`

设计要点：

- 构造函数中调用 `_disableInitializers()`，防止实现合约被初始化。
- 使用 `initialize(address owner, address feeRecipient)` 替代构造函数。
- 使用 `onlyOwner` 限制 `_authorizeUpgrade(address newImplementation)`。
- 所有状态变量必须保持稳定顺序。
- 新版本只能在末尾追加状态变量，不能改已有变量顺序或类型。
- 预留 storage gap，降低未来升级冲突风险。

示例结构：

```solidity
contract NFTMarketplaceUpgradeable is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721Receiver
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address initialFeeRecipient) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        if (initialFeeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = initialFeeRecipient;
        platformFee = 250;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

升级路线：

1. 新建 `NFTMarketplaceUpgradeable.sol`，迁移当前市场逻辑到 initializer 模式。
2. 编写部署脚本，通过 ERC1967Proxy 部署代理和实现合约。
3. 编写测试验证初始化、挂单、购买、拍卖和升级权限。
4. 新建 `NFTMarketplaceUpgradeableV2.sol`，在末尾追加新功能，例如 ERC20 支付。
5. 编写升级脚本调用 `upgradeToAndCall` 或对应 UUPS 升级入口。
6. 测试升级前后的状态保持，例如已有 listing、auction、feeRecipient、platformFee 不丢失。

测试重点：

- 实现合约不能被直接初始化。
- 代理初始化只能执行一次。
- 非 owner 不能升级。
- 升级后旧状态保持不变。
- 升级后新增功能可用。
- storage layout 不冲突。

## 9. 建议迭代顺序

建议按以下顺序推进后续改造：

1. 新建 `NFTMarketplaceUpgradeable.sol`，先把当前 ETH 市场逻辑迁移到 UUPS 架构。
2. 为 UUPS 版本补齐测试，确认升级前后状态保持。
3. 新建 V2，在 UUPS 版本上增加 ERC20 支付和出价。
4. 为 ERC20 支付增加完整测试。
5. 新增 Chainlink price oracle 模块。
6. 在 V3 或独立市场合约中接入 oracle，实现 USD 计价购买和出价。

这样做的好处是：先把升级基础打稳，再加入 ERC20 和预言机，避免一次性改动过大导致测试和安全审计难度上升。

## 10. 安全注意事项

- 私钥只能放在本地 `.env`，不能提交到 Git。
- 市场合约托管 NFT，所有涉及 NFT 和 ETH 转移的函数都应保持重入保护。
- ERC20 改造时应使用 `SafeERC20`，不要直接依赖返回值不一致的 ERC20 实现。
- Chainlink 报价必须检查 stale price。
- UUPS 升级必须严格限制 `_authorizeUpgrade` 权限。
- 可升级合约上线前需要检查 storage layout。
- 版税和平台手续费总额必须小于等于成交价。
- 拍卖退款应继续使用 pull payment 模式，减少外部调用风险。
