#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/nft-marketplace/approve-nft.sh token 1
#   ./cast/nft-marketplace/approve-nft.sh all true
#   ./cast/nft-marketplace/approve-nft.sh token 1 0xNFT
#   ./cast/nft-marketplace/approve-nft.sh all true 0xNFT

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: approve-nft.sh token|all ...}"
shift

case "$cmd" in
  token)
    token_id="${1:?Usage: approve-nft.sh token TOKEN_ID [NFT_ADDRESS]}"
    nft="${2:-$PANDA_NFT_ADDRESS}"
    send_nft "$nft" 'approve(address,uint256)' "$MARKETPLACE_ADDRESS" "$token_id"
    ;;
  all)
    approved="${1:?Usage: approve-nft.sh all true|false [NFT_ADDRESS]}"
    nft="${2:-$PANDA_NFT_ADDRESS}"
    send_nft "$nft" 'setApprovalForAll(address,bool)' "$MARKETPLACE_ADDRESS" "$approved"
    ;;
  *)
    echo "Unknown approval command: $cmd" >&2
    exit 1
    ;;
esac
