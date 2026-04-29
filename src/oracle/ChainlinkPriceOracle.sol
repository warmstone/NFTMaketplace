// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

/// @notice Chainlink price oracle for converting 18-decimal USD amounts into token amounts.
contract ChainlinkPriceOracle {
    struct FeedConfig {
        AggregatorV3Interface feed;
        uint8 tokenDecimals;
        uint256 maxStaleness;
        bool active;
    }

    address public owner;
    mapping(address => FeedConfig) public feedConfigs;

    error NotOwner();
    error ZeroAddress();
    error FeedNotActive();
    error InvalidPrice();
    error StalePrice();

    event FeedConfigured(address indexed token, address indexed feed, uint8 tokenDecimals, uint256 maxStaleness);
    event FeedDisabled(address indexed token);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /// @notice Configures a Chainlink USD price feed for a payment token.
    /// @dev Use address(0) as the token key for native ETH.
    function setFeed(address token, address feed, uint8 tokenDecimals, uint256 maxStaleness) external onlyOwner {
        if (feed == address(0)) revert ZeroAddress();

        feedConfigs[token] = FeedConfig({
            feed: AggregatorV3Interface(feed), tokenDecimals: tokenDecimals, maxStaleness: maxStaleness, active: true
        });

        emit FeedConfigured(token, feed, tokenDecimals, maxStaleness);
    }

    /// @notice Convenience helper that reads decimals from an ERC20 token.
    function setERC20Feed(address token, address feed, uint256 maxStaleness) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (feed == address(0)) revert ZeroAddress();

        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        feedConfigs[token] = FeedConfig({
            feed: AggregatorV3Interface(feed), tokenDecimals: tokenDecimals, maxStaleness: maxStaleness, active: true
        });

        emit FeedConfigured(token, feed, tokenDecimals, maxStaleness);
    }

    function disableFeed(address token) external onlyOwner {
        feedConfigs[token].active = false;
        emit FeedDisabled(token);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Converts an 18-decimal USD amount into the configured payment token amount.
    function quote(address token, uint256 usdAmount) external view returns (uint256 tokenAmount) {
        FeedConfig memory config = feedConfigs[token];
        if (!config.active) revert FeedNotActive();

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = config.feed.latestRoundData();
        if (answer <= 0 || answeredInRound < roundId) revert InvalidPrice();
        if (config.maxStaleness != 0 && block.timestamp - updatedAt > config.maxStaleness) revert StalePrice();

        uint8 feedDecimals = config.feed.decimals();
        return usdAmount * (10 ** feedDecimals) * (10 ** config.tokenDecimals) / uint256(answer) / 1e18;
    }
}
