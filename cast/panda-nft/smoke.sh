#!/usr/bin/env bash
set -euo pipefail

# Read-only health check for the deployed Sepolia PandaNFT.

# shellcheck source=./common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_cast
require_rpc

echo "Checking PandaNFT on Sepolia"
echo "contract: $PANDA_NFT_ADDRESS"
echo "caller:   $PANDA_CALLER"
echo
"$SCRIPT_DIR/read.sh" overview
echo
echo "ERC721 supported:          $("$SCRIPT_DIR/read.sh" supports 0x80ac58cd)"
echo "ERC721Metadata supported:  $("$SCRIPT_DIR/read.sh" supports 0x5b5e139f)"
echo "ERC2981 supported:         $("$SCRIPT_DIR/read.sh" supports 0x2a55205a)"
