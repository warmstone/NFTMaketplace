#!/usr/bin/env bash
set -euo pipefail

# Auction actions.
#
# Usage:
#   ./cast/nft-marketplace/auction.sh create 0xNFT 1 1eth 24
#   ./cast/nft-marketplace/auction.sh create-panda 1 1eth 24
#   ./cast/nft-marketplace/auction.sh bid 1 1.05eth
#   ./cast/nft-marketplace/auction.sh end 1
#   ./cast/nft-marketplace/auction.sh withdraw 1

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: auction.sh create|create-panda|bid|end|withdraw ...}"
shift

case "$cmd" in
  create)
    nft="${1:?Usage: auction.sh create NFT_ADDRESS TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}"
    token_id="${2:?Usage: auction.sh create NFT_ADDRESS TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}"
    start_price="$(eth_arg_to_wei "${3:?Usage: auction.sh create NFT_ADDRESS TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}")"
    duration_hours="${4:?Usage: auction.sh create NFT_ADDRESS TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}"
    send_market 'createAuction(address,uint256,uint256,uint256)(uint256)' "$nft" "$token_id" "$start_price" "$duration_hours"
    ;;
  create-panda)
    token_id="${1:?Usage: auction.sh create-panda TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}"
    start_price="$(eth_arg_to_wei "${2:?Usage: auction.sh create-panda TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}")"
    duration_hours="${3:?Usage: auction.sh create-panda TOKEN_ID START_PRICE_ETH_OR_WEI DURATION_HOURS}"
    send_market 'createAuction(address,uint256,uint256,uint256)(uint256)' "$PANDA_NFT_ADDRESS" "$token_id" "$start_price" "$duration_hours"
    ;;
  bid)
    auction_id="${1:?Usage: auction.sh bid AUCTION_ID BID_ETH_OR_WEI}"
    bid_value="$(eth_arg_to_wei "${2:?Usage: auction.sh bid AUCTION_ID BID_ETH_OR_WEI}")"
    send_market --value "$bid_value" 'placeBid(uint256)' "$auction_id"
    ;;
  end)
    auction_id="${1:?Usage: auction.sh end AUCTION_ID}"
    send_market 'endAuction(uint256)' "$auction_id"
    ;;
  withdraw)
    auction_id="${1:?Usage: auction.sh withdraw AUCTION_ID}"
    send_market 'withdrawBid(uint256)' "$auction_id"
    ;;
  *)
    echo "Unknown auction command: $cmd" >&2
    exit 1
    ;;
esac
