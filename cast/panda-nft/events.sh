#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/panda-nft/events.sh
#   ./cast/panda-nft/events.sh 5000000 latest

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cast
require_rpc

from_block="${1:-0}"
to_block="${2:-latest}"

echo "NFTMinted(address,uint256,string)"
cast logs \
  --rpc-url "$RPC_URL" \
  --from-block "$from_block" \
  --to-block "$to_block" \
  --address "$PANDA_NFT_ADDRESS" \
  'NFTMinted(address indexed,uint256 indexed,string)'

echo "MintPriceUpdated(uint256,uint256)"
cast logs \
  --rpc-url "$RPC_URL" \
  --from-block "$from_block" \
  --to-block "$to_block" \
  --address "$PANDA_NFT_ADDRESS" \
  'MintPriceUpdated(uint256,uint256)'

echo "Withdrawn(address,uint256)"
cast logs \
  --rpc-url "$RPC_URL" \
  --from-block "$from_block" \
  --to-block "$to_block" \
  --address "$PANDA_NFT_ADDRESS" \
  'Withdrawn(address indexed,uint256)'

echo "DefaultRoyaltyUpdated(address,uint96)"
cast logs \
  --rpc-url "$RPC_URL" \
  --from-block "$from_block" \
  --to-block "$to_block" \
  --address "$PANDA_NFT_ADDRESS" \
  'DefaultRoyaltyUpdated(address indexed,uint96)'

echo "TokenRoyaltyUpdated(uint256,address,uint96)"
cast logs \
  --rpc-url "$RPC_URL" \
  --from-block "$from_block" \
  --to-block "$to_block" \
  --address "$PANDA_NFT_ADDRESS" \
  'TokenRoyaltyUpdated(uint256 indexed,address indexed,uint96)'
