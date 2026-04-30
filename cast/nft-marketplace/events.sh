#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/nft-marketplace/events.sh
#   ./cast/nft-marketplace/events.sh 5000000 latest

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cast
require_rpc

from_block="${1:-0}"
to_block="${2:-latest}"

log_event() {
  local title="$1"
  local sig="$2"
  echo "$title"
  cast logs \
    --rpc-url "$RPC_URL" \
    --from-block "$from_block" \
    --to-block "$to_block" \
    --address "$MARKETPLACE_ADDRESS" \
    "$sig"
}

log_event "NFTListed(uint256,address,address,uint256,uint256)" 'NFTListed(uint256 indexed,address indexed,address indexed,uint256,uint256)'
log_event "NFTDelisted(uint256)" 'NFTDelisted(uint256 indexed)'
log_event "NFTPriceUpdated(uint256,uint256,uint256)" 'NFTPriceUpdated(uint256 indexed,uint256,uint256)'
log_event "NFTSold(uint256,address,address,uint256)" 'NFTSold(uint256 indexed,address indexed,address indexed,uint256)'
log_event "AuctionCreated(uint256,address,address,uint256,uint256,uint256)" 'AuctionCreated(uint256 indexed,address indexed,address indexed,uint256,uint256,uint256)'
log_event "BidPlaced(uint256,address,uint256)" 'BidPlaced(uint256 indexed,address indexed,uint256)'
log_event "AuctionEnded(uint256,address,uint256)" 'AuctionEnded(uint256 indexed,address indexed,uint256)'
log_event "BidWithdrawn(uint256,address,uint256)" 'BidWithdrawn(uint256 indexed,address indexed,uint256)'
log_event "PlatformFeeUpdated(uint256,uint256)" 'PlatformFeeUpdated(uint256,uint256)'
log_event "FeeRecipientUpdated(address,address)" 'FeeRecipientUpdated(address indexed,address indexed)'
