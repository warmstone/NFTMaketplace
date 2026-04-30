#!/usr/bin/env bash
set -euo pipefail

# Fee recipient only actions.
#
# Usage:
#   ./cast/nft-marketplace/admin.sh set-platform-fee 500
#   ./cast/nft-marketplace/admin.sh update-fee-recipient 0xNewRecipient

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

cmd="${1:?Usage: admin.sh set-platform-fee|update-fee-recipient ...}"
shift

case "$cmd" in
  set-platform-fee)
    fee_bps="${1:?Usage: admin.sh set-platform-fee FEE_BPS}"
    send_market 'setPlatformFee(uint256)' "$fee_bps"
    ;;
  update-fee-recipient)
    recipient="${1:?Usage: admin.sh update-fee-recipient NEW_RECIPIENT}"
    send_market 'updateFeeRecipient(address)' "$recipient"
    ;;
  *)
    echo "Unknown admin command: $cmd" >&2
    exit 1
    ;;
esac
