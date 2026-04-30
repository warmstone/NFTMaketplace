#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./cast/panda-nft/read.sh overview
#   ./cast/panda-nft/read.sh token 1
#   ./cast/panda-nft/read.sh balance 0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6
#   ./cast/panda-nft/read.sh royalty 1 1ether
#   ./cast/panda-nft/read.sh supports 0x2a55205a

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

cmd="${1:-overview}"
shift || true

case "$cmd" in
  overview)
    echo "contract=$PANDA_NFT_ADDRESS"
    echo "caller=$PANDA_CALLER"
    echo "name=$(read_call 'name()(string)')"
    echo "symbol=$(read_call 'symbol()(string)')"
    echo "owner=$(read_call 'owner()(address)')"
    echo "mintPrice=$(read_call 'mintPrice()(uint256)') wei"
    echo "totalSupply=$(read_call 'totalSupply()(uint256)')"
    echo "maxSupply=$(read_call 'MAX_SUPPLY()(uint256)')"
    echo "paused=$(read_call 'paused()(bool)')"
    echo "contractBalance=$(cast balance --rpc-url "$RPC_URL" "$PANDA_NFT_ADDRESS") wei"
    echo "callerBalance=$(cast balance --rpc-url "$RPC_URL" "$PANDA_CALLER") wei"
    ;;
  token)
    token_id="${1:?Usage: read.sh token TOKEN_ID}"
    echo "ownerOf=$(read_call 'ownerOf(uint256)(address)' "$token_id")"
    echo "tokenURI=$(read_call 'tokenURI(uint256)(string)' "$token_id")"
    echo "approved=$(read_call 'getApproved(uint256)(address)' "$token_id")"
    ;;
  balance)
    account="${1:-$PANDA_CALLER}"
    read_call 'balanceOf(address)(uint256)' "$account"
    ;;
  owner-of)
    token_id="${1:?Usage: read.sh owner-of TOKEN_ID}"
    read_call 'ownerOf(uint256)(address)' "$token_id"
    ;;
  token-uri)
    token_id="${1:?Usage: read.sh token-uri TOKEN_ID}"
    read_call 'tokenURI(uint256)(string)' "$token_id"
    ;;
  approved)
    token_id="${1:?Usage: read.sh approved TOKEN_ID}"
    read_call 'getApproved(uint256)(address)' "$token_id"
    ;;
  operator)
    owner="${1:?Usage: read.sh operator OWNER OPERATOR}"
    operator="${2:?Usage: read.sh operator OWNER OPERATOR}"
    read_call 'isApprovedForAll(address,address)(bool)' "$owner" "$operator"
    ;;
  royalty)
    token_id="${1:?Usage: read.sh royalty TOKEN_ID SALE_PRICE_OR_ETH}"
    sale_price="${2:?Usage: read.sh royalty TOKEN_ID SALE_PRICE_OR_ETH}"
    if [[ "$sale_price" == *ether ]]; then
      sale_price="$(to_wei "${sale_price%ether}")"
    fi
    read_call 'royaltyInfo(uint256,uint256)(address,uint256)' "$token_id" "$sale_price"
    ;;
  supports)
    interface_id="${1:?Usage: read.sh supports INTERFACE_ID}"
    read_call 'supportsInterface(bytes4)(bool)' "$interface_id"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
