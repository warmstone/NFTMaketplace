// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ChainlinkPriceOracle} from "../src/oracle/ChainlinkPriceOracle.sol";

contract ChainlinkPriceOracleTest is Test {
    ChainlinkPriceOracle public oracle;
    MockV3Aggregator public feed;
    ERC20Mock public token;

    address public owner = address(this);
    address public user = address(0x1);

    function setUp() public {
        oracle = new ChainlinkPriceOracle(owner);
        feed = new MockV3Aggregator(8, 2_000e8);
        token = new ERC20Mock();
    }

    function testOwnerCanConfigureFeedAndQuoteTokenAmount() public {
        oracle.setERC20Feed(address(token), address(feed), 1 hours);

        uint256 tokenAmount = oracle.quote(address(token), 100e18);

        assertEq(tokenAmount, 0.05 ether);
    }

    function testQuoteRevertsForStalePrice() public {
        oracle.setERC20Feed(address(token), address(feed), 1 hours);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.expectRevert(ChainlinkPriceOracle.StalePrice.selector);
        oracle.quote(address(token), 100e18);
    }

    function testQuoteRevertsForInvalidPrice() public {
        oracle.setERC20Feed(address(token), address(feed), 1 hours);
        feed.updateAnswer(0);

        vm.expectRevert(ChainlinkPriceOracle.InvalidPrice.selector);
        oracle.quote(address(token), 100e18);
    }

    function testNonOwnerCannotConfigureFeed() public {
        vm.expectRevert(ChainlinkPriceOracle.NotOwner.selector);
        vm.prank(user);
        oracle.setERC20Feed(address(token), address(feed), 1 hours);
    }
}

contract MockV3Aggregator {
    uint8 public immutable decimals;
    int256 public answer;
    uint80 public roundId = 1;
    uint256 public updatedAt;

    constructor(uint8 feedDecimals, int256 initialAnswer) {
        decimals = feedDecimals;
        answer = initialAnswer;
        updatedAt = block.timestamp;
    }

    function updateAnswer(int256 newAnswer) external {
        answer = newAnswer;
        roundId++;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 currentRoundId,
            int256 currentAnswer,
            uint256 startedAt,
            uint256 currentUpdatedAt,
            uint80 answeredInRound
        )
    {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}
