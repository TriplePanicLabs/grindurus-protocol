// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

contract URUSStrategy {

    address owner;

    AggregatorV3Interface public oracleETHUSD;

    

    uint256 public totalPositions;

    mapping (uint256 index => uint64) public lastActionTimestamp;

    mapping (uint256 index => PositionLong) public longs;

    mapping (uint256 index => PositionHedge) public hedges;

    mapping (uint256 index => PositionClose) public closed;

    constructor (address _oracleETHUSD, address _baseToken, address _quoteToken) {
        owner = msg.sender;
        oracleETHUSD = AggregatorV3Interface(_oracleETHUSD);
        
    }

    struct PositionLong {
        uint256 index;
        uint8 buy_number_max;
        uint8 buy_number;

        uint256 buy_price_max;          // [buy_price_max] = USDT / ETH
        uint256 buy_price_min;          // [buy_price_min] = USDT / ETH
        uint256 buy_init_qty;           // [buy_init_qty] = ETH
        uint256 buy_init_price;         // [buy_init_price] = USDT / ETH
        uint256 buy_qty;                // [buy_qty] = ETH
        uint256 buy_price;              // [buy_price] = USDT / ETH
        uint256 buy_commission_qty;     // [buy_commission_qty] = ETH
        uint256 buy_commission_price;   // [buy_commission_price] = USDT / ETH
    }

    struct PositionHedge {
        uint256 index;
        
        uint8 usell_number_max;
        uint8 usell_number;
        uint256 usell_price_max;
        uint256 usell_price_min;
        uint256 usell_init_qty;
        uint256 usell_init_price;
        uint256 usell_qty;              
        uint256 usell_price;
        uint256 usell_commission_qty;   // [usell_commission_qty] = ETH
        uint256 usell_commission_price; // [usell_commission_price] = USDT / ETH
    }

    struct PositionClose {
        uint256 index;

        uint256 sell_number_max;
        uint256 sell_number;
        uint256 sell_qty;
        uint256 sell_price;
        uint256 sell_commission_qty;
        uint256 sell_commission_price;
        uint256 profit;
    }

    function buy() {
        uint256 index = totalPositions;
        PositionLong storage long = longs[index];
        long.index = index;
        
        // buy p
        long.

        totalPositions++;
    }

    function extra_buy() {

    }

    function sell() {

    }
    
    function under_sell() {

    }

    function grid_sell() {

    }

    function rebuy() {

    }

    function rebalance() {

    }
}