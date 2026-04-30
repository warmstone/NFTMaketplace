#!/usr/bin/env bash
set -euo pipefail

# ERC721 write actions.
#
# Usage:
#   ./cast/panda-nft/erc721.sh approve 0xSpender 1
#   ./cast/panda-nft/erc721.sh set-approval-for-all 0xOperator true
#   ./cast/panda-nft/erc721.sh transfer 0xTo 1
#   ./cast/panda-nft/erc721.sh transfer-from 0xFrom 0xTo 1

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: erc721.sh approve|set-approval-for-all|transfer|transfer-from ...}"
shift

case "$cmd" in
  approve)
    spender="${1:?Usage: erc721.sh approve SPENDER TOKEN_ID}"
    token_id="${2:?Usage: erc721.sh approve SPENDER TOKEN_ID}"
    send_tx 'approve(address,uint256)' "$spender" "$token_id"
    ;;
  set-approval-for-all)
    operator="${1:?Usage: erc721.sh set-approval-for-all OPERATOR true|false}"
    approved="${2:?Usage: erc721.sh set-approval-for-all OPERATOR true|false}"
    send_tx 'setApprovalForAll(address,bool)' "$operator" "$approved"
    ;;
  transfer)
    to="${1:?Usage: erc721.sh transfer TO TOKEN_ID}"
    token_id="${2:?Usage: erc721.sh transfer TO TOKEN_ID}"
    send_tx 'safeTransferFrom(address,address,uint256)' "$PANDA_CALLER" "$to" "$token_id"
    ;;
  transfer-from)
    from="${1:?Usage: erc721.sh transfer-from FROM TO TOKEN_ID}"
    to="${2:?Usage: erc721.sh transfer-from FROM TO TOKEN_ID}"
    token_id="${3:?Usage: erc721.sh transfer-from FROM TO TOKEN_ID}"
    send_tx 'safeTransferFrom(address,address,uint256)' "$from" "$to" "$token_id"
    ;;
  *)
    echo "Unknown ERC721 command: $cmd" >&2
    exit 1
    ;;
esac
