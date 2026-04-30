#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

if [ -d "$HOME/.foundry/bin" ]; then
  export PATH="$HOME/.foundry/bin:$PATH"
fi

if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.env"
  set +a
fi

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

MARKETPLACE_ADDRESS="${MARKETPLACE_ADDRESS:-0xf1754633738a7d912a1a139cc7959f4853905fa4}"
MARKETPLACE_CALLER="${MARKETPLACE_CALLER:-0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6}"
PANDA_NFT_ADDRESS="${PANDA_NFT_ADDRESS:-0xb5ce1677188754fff3c5df158a5e14c0b61c0858}"
RPC_URL="${RPC_URL:-${SEPOLIA_RPC:-}}"
CHAIN_ID="${CHAIN_ID:-11155111}"

require_rpc() {
  if [ -z "${RPC_URL}" ]; then
    echo "Missing RPC_URL or SEPOLIA_RPC. Set it in .env or cast/nft-marketplace/.env." >&2
    exit 1
  fi
}

require_cast() {
  if ! command -v cast >/dev/null 2>&1; then
    echo "cast not found. Install Foundry or add ~/.foundry/bin to PATH." >&2
    exit 1
  fi
}

sender_args() {
  if [ -n "${MARKETPLACE_PRIVATE_KEY:-}" ]; then
    printf '%s\n' "--private-key" "$MARKETPLACE_PRIVATE_KEY"
    return
  fi

  if [ -n "${PANDA_PRIVATE_KEY:-}" ]; then
    printf '%s\n' "--private-key" "$PANDA_PRIVATE_KEY"
    return
  fi

  if [ -n "${PRIVATE_KEY:-}" ]; then
    printf '%s\n' "--private-key" "$PRIVATE_KEY"
    return
  fi

  if [ -n "${CAST_ACCOUNT:-}" ]; then
    printf '%s\n' "--account" "$CAST_ACCOUNT"
    return
  fi

  echo "Missing signer. Set MARKETPLACE_PRIVATE_KEY/PRIVATE_KEY or CAST_ACCOUNT for $MARKETPLACE_CALLER." >&2
  exit 1
}

read_market() {
  require_cast
  require_rpc
  cast call --rpc-url "$RPC_URL" "$MARKETPLACE_ADDRESS" "$@"
}

read_nft() {
  require_cast
  require_rpc
  local nft="${1:?nft address required}"
  shift
  cast call --rpc-url "$RPC_URL" "$nft" "$@"
}

send_market() {
  require_cast
  require_rpc
  local signer
  mapfile -t signer < <(sender_args)

  cast send \
    --rpc-url "$RPC_URL" \
    --chain "$CHAIN_ID" \
    --from "$MARKETPLACE_CALLER" \
    "${signer[@]}" \
    "$MARKETPLACE_ADDRESS" \
    "$@"
}

send_nft() {
  require_cast
  require_rpc
  local nft="${1:?nft address required}"
  shift
  local signer
  mapfile -t signer < <(sender_args)

  cast send \
    --rpc-url "$RPC_URL" \
    --chain "$CHAIN_ID" \
    --from "$MARKETPLACE_CALLER" \
    "${signer[@]}" \
    "$nft" \
    "$@"
}

to_wei() {
  require_cast
  cast to-wei "$1" ether | uint_value
}

uint_value() {
  awk '/^[0-9]/ {print $1; exit}'
}

eth_arg_to_wei() {
  local value="${1:?amount required}"
  if [[ "$value" == *ether ]]; then
    to_wei "${value%ether}"
  elif [[ "$value" == *eth ]]; then
    to_wei "${value%eth}"
  elif [[ "$value" == *wei ]]; then
    printf '%s\n' "${value%wei}"
  elif [[ "$value" == *.* ]]; then
    to_wei "$value"
  else
    printf '%s\n' "$value"
  fi
}
