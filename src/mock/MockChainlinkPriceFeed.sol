// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ChainlinkPriceFeed } from "../presale/ChainlinkPriceFeed.sol";

/**
 * @title MockChainlinkPriceFeed
 * @notice Mock implementation of ChainlinkPriceFeed for testing
 */
contract MockChainlinkPriceFeed is ChainlinkPriceFeed {
    int256 public price;
    uint80 public roundId;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;
    uint8 public constant DECIMALS = 8;

    constructor(int256 _initialPrice) {
        price = _initialPrice;
        roundId = 1;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    function setPrice(int256 _newPrice) external {
        price = _newPrice;
        roundId++;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    function setPriceWithTimestamp(int256 _newPrice, uint256 _timestamp) external {
        price = _newPrice;
        roundId++;
        updatedAt = _timestamp;
        answeredInRound = roundId;
    }
}

