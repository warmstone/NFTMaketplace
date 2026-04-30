# PandaNFT cast scripts

这些脚本默认调用 Sepolia 上的 `PandaNFT`：

- Contract: `0xb5ce1677188754fff3c5df158a5e14c0b61c0858`
- Caller: `0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6`
- Chain ID: `11155111`

## 配置

先设置 RPC 和签名方式。脚本会读取项目根目录 `.env`，也会读取本目录的 `.env`。

```bash
cp cast/panda-nft/.env.example cast/panda-nft/.env
```

写交易必须能用 `0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6` 签名。二选一：

```bash
PANDA_PRIVATE_KEY=你的_0x59D..._私钥
```

或者使用 Foundry keystore：

```bash
cast wallet import panda-sepolia --interactive
CAST_ACCOUNT=panda-sepolia
```

只知道账户地址不能发送交易，必须有对应私钥或 keystore。

## 只读查询

```bash
./cast/panda-nft/smoke.sh
./cast/panda-nft/read.sh overview
./cast/panda-nft/read.sh balance 0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6
./cast/panda-nft/read.sh token 1
./cast/panda-nft/read.sh owner-of 1
./cast/panda-nft/read.sh token-uri 1
./cast/panda-nft/read.sh approved 1
./cast/panda-nft/read.sh operator 0xOwner 0xOperator
./cast/panda-nft/read.sh royalty 1 1ether
./cast/panda-nft/read.sh supports 0x80ac58cd
./cast/panda-nft/read.sh supports 0x5b5e139f
./cast/panda-nft/read.sh supports 0x2a55205a
```

## 铸造

```bash
./cast/panda-nft/mint.sh ipfs://CID/metadata.json
./cast/panda-nft/mint.sh ipfs://CID/metadata.json 0.01
```

不传价格时，脚本会先读取链上的 `mintPrice()` 并用精确金额发送。

## owner 管理

以下命令要求 `0x59D...` 是合约 owner，否则会 revert。

```bash
./cast/panda-nft/owner-admin.sh set-price 0.02
./cast/panda-nft/owner-admin.sh set-default-royalty 0xReceiver 500
./cast/panda-nft/owner-admin.sh set-token-royalty 1 0xReceiver 750
./cast/panda-nft/owner-admin.sh pause
./cast/panda-nft/owner-admin.sh unpause
./cast/panda-nft/owner-admin.sh withdraw
```

## ERC721 授权和转移

```bash
./cast/panda-nft/erc721.sh approve 0xSpender 1
./cast/panda-nft/erc721.sh set-approval-for-all 0xOperator true
./cast/panda-nft/erc721.sh transfer 0xTo 1
./cast/panda-nft/erc721.sh transfer-from 0xFrom 0xTo 1
```

## 事件

```bash
./cast/panda-nft/events.sh
./cast/panda-nft/events.sh 5000000 latest
```
