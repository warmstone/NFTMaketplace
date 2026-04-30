#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/nft-marketplace/read.sh overview
#   ./cast/nft-marketplace/read.sh listing 1
#   ./cast/nft-marketplace/read.sh auction 1
#   ./cast/nft-marketplace/read.sh pending 1 0xBidder
#   ./cast/nft-marketplace/read.sh nft-status 0xb5ce... 1

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:-overview}"
shift || true

case "$cmd" in
  overview)
    echo "marketplace=$MARKETPLACE_ADDRESS"
    echo "caller=$MARKETPLACE_CALLER"
    echo "pandaNFT=$PANDA_NFT_ADDRESS"
    echo "feeRecipient=$(read_market 'feeRecipient()(address)')"
    echo "platformFee=$(read_market 'platformFee()(uint256)' | uint_value) bps"
    echo "listingCounter=$(read_market 'listingCounter()(uint256)' | uint_value)"
    echo "auctionCounter=$(read_market 'auctionCounter()(uint256)' | uint_value)"
    echo "basisPoints=$(read_market 'BASIS_POINTS()(uint256)' | uint_value)"
    echo "maxPlatformFee=$(read_market 'MAX_PLATFORM_FEE()(uint256)' | uint_value) bps"
    echo "minBidIncrement=$(read_market 'MIN_BID_INCREMENT_BPS()(uint256)' | uint_value) bps"
    echo "marketBalance=$(cast balance --rpc-url "$RPC_URL" "$MARKETPLACE_ADDRESS") wei"
    echo "callerBalance=$(cast balance --rpc-url "$RPC_URL" "$MARKETPLACE_CALLER") wei"
    ;;
  listing)
    listing_id="${1:?Usage: read.sh listing LISTING_ID}"
    read_market 'getListing(uint256)(address,address,uint256,uint256,bool)' "$listing_id"
    ;;
  listing-raw)
    listing_id="${1:?Usage: read.sh listing-raw LISTING_ID}"
    read_market 'listings(uint256)(address,address,uint256,uint256,bool)' "$listing_id"
    ;;
  auction)
    auction_id="${1:?Usage: read.sh auction AUCTION_ID}"
    read_market 'getAuction(uint256)(address,address,uint256,uint256,uint256,address,uint256,bool)' "$auction_id"
    ;;
  auction-raw)
    auction_id="${1:?Usage: read.sh auction-raw AUCTION_ID}"
    read_market 'auctions(uint256)(address,address,uint256,uint256,uint256,address,uint256,bool)' "$auction_id"
    ;;
  pending)
    auction_id="${1:?Usage: read.sh pending AUCTION_ID BIDDER}"
    bidder="${2:-$MARKETPLACE_CALLER}"
    read_market 'pendingReturns(uint256,address)(uint256)' "$auction_id" "$bidder"
    ;;
  fee-recipient)
    read_market 'feeRecipient()(address)'
    ;;
  platform-fee)
    read_market 'platformFee()(uint256)'
    ;;
  nft-status)
    nft="${1:-$PANDA_NFT_ADDRESS}"
    token_id="${2:?Usage: read.sh nft-status [NFT_ADDRESS] TOKEN_ID}"
    echo "ownerOf=$(read_nft "$nft" 'ownerOf(uint256)(address)' "$token_id")"
    echo "approved=$(read_nft "$nft" 'getApproved(uint256)(address)' "$token_id")"
    echo "operatorApproved=$(read_nft "$nft" 'isApprovedForAll(address,address)(bool)' "$MARKETPLACE_CALLER" "$MARKETPLACE_ADDRESS")"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
