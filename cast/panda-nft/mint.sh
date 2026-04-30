#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/panda-nft/mint.sh ipfs://CID/metadata.json
#   ./cast/panda-nft/mint.sh ipfs://CID/metadata.json 0.01

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

uri="${1:?Usage: mint.sh TOKEN_URI [PRICE_IN_ETH]}"
price_eth="${2:-}"

if [ -n "$price_eth" ]; then
  value="$(to_wei "$price_eth")"
else
  value="$(read_call 'mintPrice()(uint256)' | uint_value)"
fi

send_tx \
  --value "$value" \
  'mint(string)(uint256)' \
  "$uri"
