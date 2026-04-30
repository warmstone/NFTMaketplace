#!/usr/bin/env bash
set -euo pipefail

# Fixed-price listing actions.
#
# Usage:
#   ./cast/nft-marketplace/listing.sh list 0xNFT 1 1eth
#   ./cast/nft-marketplace/listing.sh list-panda 1 1eth
#   ./cast/nft-marketplace/listing.sh buy 1 1eth
#   ./cast/nft-marketplace/listing.sh buy 1
#   ./cast/nft-marketplace/listing.sh update-price 1 2eth
#   ./cast/nft-marketplace/listing.sh delist 1

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: listing.sh list|list-panda|buy|update-price|delist ...}"
shift

case "$cmd" in
  list)
    nft="${1:?Usage: listing.sh list NFT_ADDRESS TOKEN_ID PRICE_ETH_OR_WEI}"
    token_id="${2:?Usage: listing.sh list NFT_ADDRESS TOKEN_ID PRICE_ETH_OR_WEI}"
    price="$(eth_arg_to_wei "${3:?Usage: listing.sh list NFT_ADDRESS TOKEN_ID PRICE_ETH_OR_WEI}")"
    send_market 'listNFT(address,uint256,uint256)(uint256)' "$nft" "$token_id" "$price"
    ;;
  list-panda)
    token_id="${1:?Usage: listing.sh list-panda TOKEN_ID PRICE_ETH_OR_WEI}"
    price="$(eth_arg_to_wei "${2:?Usage: listing.sh list-panda TOKEN_ID PRICE_ETH_OR_WEI}")"
    send_market 'listNFT(address,uint256,uint256)(uint256)' "$PANDA_NFT_ADDRESS" "$token_id" "$price"
    ;;
  buy)
    listing_id="${1:?Usage: listing.sh buy LISTING_ID [PRICE_ETH_OR_WEI]}"
    if [ -n "${2:-}" ]; then
      value="$(eth_arg_to_wei "$2")"
    else
      value="$(read_market 'getListing(uint256)(address,address,uint256,uint256,bool)' "$listing_id" | awk 'NR==4 {print $1}')"
    fi
    send_market --value "$value" 'buyNFT(uint256)' "$listing_id"
    ;;
  update-price)
    listing_id="${1:?Usage: listing.sh update-price LISTING_ID NEW_PRICE_ETH_OR_WEI}"
    price="$(eth_arg_to_wei "${2:?Usage: listing.sh update-price LISTING_ID NEW_PRICE_ETH_OR_WEI}")"
    send_market 'updatePrice(uint256,uint256)' "$listing_id" "$price"
    ;;
  delist)
    listing_id="${1:?Usage: listing.sh delist LISTING_ID}"
    send_market 'delistNFT(uint256)' "$listing_id"
    ;;
  *)
    echo "Unknown listing command: $cmd" >&2
    exit 1
    ;;
esac
