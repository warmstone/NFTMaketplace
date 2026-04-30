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

PANDA_NFT_ADDRESS="${PANDA_NFT_ADDRESS:-0xb5ce1677188754fff3c5df158a5e14c0b61c0858}"
PANDA_CALLER="${PANDA_CALLER:-0x59D67d644cC41BC875F08D5ef899B649D7e8D1a6}"
RPC_URL="${RPC_URL:-${SEPOLIA_RPC:-}}"
CHAIN_ID="${CHAIN_ID:-11155111}"

require_rpc() {
  if [ -z "${RPC_URL}" ]; then
    echo "Missing RPC_URL or SEPOLIA_RPC. Set it in .env or cast/panda-nft/.env." >&2
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

  echo "Missing signer. Set PANDA_PRIVATE_KEY/PRIVATE_KEY or CAST_ACCOUNT for $PANDA_CALLER." >&2
  exit 1
}

read_call() {
  require_cast
  require_rpc
  cast call --rpc-url "$RPC_URL" "$PANDA_NFT_ADDRESS" "$@"
}

send_tx() {
  require_cast
  require_rpc
  local signer
  mapfile -t signer < <(sender_args)

  cast send \
    --rpc-url "$RPC_URL" \
    --chain "$CHAIN_ID" \
    --from "$PANDA_CALLER" \
    "${signer[@]}" \
    "$PANDA_NFT_ADDRESS" \
    "$@"
}

to_wei() {
  require_cast
  cast to-wei "$1" ether | uint_value
}

uint_value() {
  awk '/^[0-9]/ {print $1; exit}'
}
