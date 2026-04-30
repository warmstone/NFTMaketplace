#!/usr/bin/env bash
set -euo pipefail

# Owner-only PandaNFT actions.
#
# Usage:
#   ./cast/panda-nft/owner-admin.sh set-price 0.02
#   ./cast/panda-nft/owner-admin.sh set-default-royalty 0xReceiver 500
#   ./cast/panda-nft/owner-admin.sh set-token-royalty 1 0xReceiver 750
#   ./cast/panda-nft/owner-admin.sh pause
#   ./cast/panda-nft/owner-admin.sh unpause
#   ./cast/panda-nft/owner-admin.sh withdraw

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: owner-admin.sh set-price|set-default-royalty|set-token-royalty|pause|unpause|withdraw ...}"
shift

case "$cmd" in
  set-price)
    price_eth="${1:?Usage: owner-admin.sh set-price PRICE_IN_ETH}"
    send_tx 'setMintPrice(uint256)' "$(to_wei "$price_eth")"
    ;;
  set-default-royalty)
    receiver="${1:?Usage: owner-admin.sh set-default-royalty RECEIVER BPS}"
    bps="${2:?Usage: owner-admin.sh set-default-royalty RECEIVER BPS}"
    send_tx 'setDefaultRoyalty(address,uint96)' "$receiver" "$bps"
    ;;
  set-token-royalty)
    token_id="${1:?Usage: owner-admin.sh set-token-royalty TOKEN_ID RECEIVER BPS}"
    receiver="${2:?Usage: owner-admin.sh set-token-royalty TOKEN_ID RECEIVER BPS}"
    bps="${3:?Usage: owner-admin.sh set-token-royalty TOKEN_ID RECEIVER BPS}"
    send_tx 'setTokenRoyalty(uint256,address,uint96)' "$token_id" "$receiver" "$bps"
    ;;
  pause)
    send_tx 'pause()'
    ;;
  unpause)
    send_tx 'unpause()'
    ;;
  withdraw)
    send_tx 'withdraw()'
    ;;
  *)
    echo "Unknown owner command: $cmd" >&2
    exit 1
    ;;
esac
