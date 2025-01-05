// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";

contract PriceOracleSelf is AggregatorV3Interface {

    int256 private price;

    constructor () {
        price = int256(10 ** decimals());
    }

    function decimals() public pure returns (uint8) {
        return 8;
    }

    function description() public pure returns (string memory) {
        return "SelfOracle";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) 
    {
        roundId = 0;
        answer = price;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

}
