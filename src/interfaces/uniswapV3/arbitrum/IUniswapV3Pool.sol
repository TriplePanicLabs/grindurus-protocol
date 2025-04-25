// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for a Uniswap V3 Pool
interface IUniswapV3Pool {

    function initialize(uint160 sqrtPriceX96) external;

}