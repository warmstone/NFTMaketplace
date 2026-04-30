# NFTMarketplace cast scripts

这些脚本默认调用 Sepolia 上的 `NFTMarketplace`：

- Marketplace: `0xf1754633738a7d912a1a139cc7959f4853905fa4`
- Caller: `0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6`
- PandaNFT: `0xb5ce1677188754fff3c5df158a5e14c0b61c0858`
- Chain ID: `11155111`

## 配置

脚本会读取项目根目录 `.env`，也会读取本目录的 `.env`。

```bash
cp cast/nft-marketplace/.env.example cast/nft-marketplace/.env
```

写交易必须能用 `MARKETPLACE_CALLER` 签名。二选一：

```bash
MARKETPLACE_PRIVATE_KEY=你的_0x59D..._私钥
```

或者使用 Foundry keystore：

```bash
cast wallet import marketplace-sepolia --interactive
CAST_ACCOUNT=marketplace-sepolia
```

## 只读查询

```bash
./cast/nft-marketplace/smoke.sh
./cast/nft-marketplace/read.sh overview
./cast/nft-marketplace/read.sh listing 1
./cast/nft-marketplace/read.sh auction 1
./cast/nft-marketplace/read.sh pending 1 0xBidder
./cast/nft-marketplace/read.sh nft-status 0xb5ce1677188754fff3c5df158a5e14c0b61c0858 1
```

## 上架前授权

`listNFT` 和 `createAuction` 会把 NFT 托管到市场合约，所以 NFT owner 必须先授权 marketplace。

```bash
./cast/nft-marketplace/approve-nft.sh token 1
./cast/nft-marketplace/approve-nft.sh all true
./cast/nft-marketplace/approve-nft.sh token 1 0xOtherNFT
./cast/nft-marketplace/approve-nft.sh all true 0xOtherNFT
```

## 固定价格

价格参数支持 `1eth`、`1ether`、`1.0`、`1000000000000000000wei`。纯整数会按 wei 处理，小数会按 ether 处理。

```bash
./cast/nft-marketplace/listing.sh list-panda 1 1eth
./cast/nft-marketplace/listing.sh list 0xNFT 1 1eth
./cast/nft-marketplace/listing.sh update-price 1 2eth
./cast/nft-marketplace/listing.sh buy 1
./cast/nft-marketplace/listing.sh buy 1 1eth
./cast/nft-marketplace/listing.sh delist 1
```

`buy 1` 不传价格时会从链上读取 listing price 并精确支付。

## 拍卖

`durationHours` 必须大于 `1`，加价必须至少比当前最高价高 `5%`。

```bash
./cast/nft-marketplace/auction.sh create-panda 1 1eth 24
./cast/nft-marketplace/auction.sh create 0xNFT 1 1eth 24
./cast/nft-marketplace/auction.sh bid 1 1.05eth
./cast/nft-marketplace/auction.sh end 1
./cast/nft-marketplace/auction.sh withdraw 1
```

## 费用管理员

以下命令要求 `MARKETPLACE_CALLER` 是当前 `feeRecipient`。

```bash
./cast/nft-marketplace/admin.sh set-platform-fee 500
./cast/nft-marketplace/admin.sh update-fee-recipient 0xNewRecipient
```

## 事件

```bash
./cast/nft-marketplace/events.sh
./cast/nft-marketplace/events.sh 5000000 latest
```
