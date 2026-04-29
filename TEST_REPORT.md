# Test Report

## Summary

- Date: 2026-04-29
- Command: `forge test -vvv`
- Compiler: Solc 0.8.34
- Result: Passed
- Test suites: 4
- Total tests: 49
- Passed: 49
- Failed: 0
- Skipped: 0

## Test Suites

### `test/PandaNFTTest.t.sol:PandaNFTTest`

- Result: Passed
- Tests: 24 passed, 0 failed, 0 skipped
- Suite time: 12.92ms

Covered behavior:

- Deployment metadata, owner, mint price, total supply, and pause state
- Minting success path, token URI storage, event emission, and token id increments
- Mint payment validation for insufficient and excessive ETH
- Empty token URI rejection
- Mint price updates and access control
- Owner withdrawals and empty-balance rejection
- Pause and unpause behavior
- Default and token-specific ERC2981 royalty configuration
- ERC721 metadata and ERC2981 interface support

### `test/NFTMarketplaceTest.t.sol:NFTMarketplaceTest`

- Result: Passed
- Tests: 13 passed, 0 failed, 0 skipped
- Suite time: 12.90ms

Covered behavior:

- Marketplace constructor initialization
- Fixed-price listing escrow and event emission
- Price updates
- Exact-payment purchase validation
- NFT transfer, royalty payout, platform fee payout, and seller proceeds
- Delisting and escrow return
- Auction creation and escrow
- Auction settlement with and without bids
- Outbid bidder refunds through pending returns
- Fee recipient and platform fee updates
- Duplicate order prevention for escrowed tokens
- Reversion when royalty plus fee exceeds sale price

### `test/NFTMarketplaceUpgradeableTest.t.sol:NFTMarketplaceUpgradeableTest`

- Result: Passed
- Tests: 8 passed, 0 failed, 0 skipped
- Suite time: 8.54ms

Covered behavior:

- UUPS proxy initialization
- Implementation contract initialization lock
- Owner-only upgrade authorization
- Upgrade from base marketplace to V2
- Existing ETH marketplace state remains usable after upgrade
- ERC20 fixed-price purchase and payout distribution
- ERC20 auction bidding, outbid withdrawal, and settlement
- Rejection of unapproved ERC20 payment tokens
- V3 USD-denominated ERC20 purchase through the Chainlink-style oracle

### `test/ChainlinkPriceOracleTest.t.sol:ChainlinkPriceOracleTest`

- Result: Passed
- Tests: 4 passed, 0 failed, 0 skipped
- Suite time: 9.42ms

Covered behavior:

- Owner-only feed configuration
- ERC20 feed decimal discovery
- USD-to-token quoting with Chainlink-style feed data
- Rejection of stale prices
- Rejection of invalid prices

## Full Result

```text
Ran 24 tests for test/PandaNFTTest.t.sol:PandaNFTTest
Suite result: ok. 24 passed; 0 failed; 0 skipped; finished in 12.92ms (6.90ms CPU time)

Ran 13 tests for test/NFTMarketplaceTest.t.sol:NFTMarketplaceTest
Suite result: ok. 13 passed; 0 failed; 0 skipped; finished in 12.90ms (20.41ms CPU time)

Ran 8 tests for test/NFTMarketplaceUpgradeableTest.t.sol:NFTMarketplaceUpgradeableTest
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 8.54ms (4.90ms CPU time)

Ran 4 tests for test/ChainlinkPriceOracleTest.t.sol:ChainlinkPriceOracleTest
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 9.42ms (3.02ms CPU time)

Ran 4 test suites in 88.04ms (35.21ms CPU time): 49 tests passed, 0 failed, 0 skipped (49 total tests)
```
