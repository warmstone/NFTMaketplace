#!/usr/bin/env bash
set -euo pipefail

# Read-only health check for the deployed Sepolia NFTMarketplace.

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cast
require_rpc

echo "Checking NFTMarketplace on Sepolia"
echo "marketplace: $MARKETPLACE_ADDRESS"
echo "caller:      $MARKETPLACE_CALLER"
echo "pandaNFT:    $PANDA_NFT_ADDRESS"
echo
"$SCRIPT_DIR/read.sh" overview
