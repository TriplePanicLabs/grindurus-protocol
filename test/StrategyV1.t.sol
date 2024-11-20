// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
// import {PositionsNFT} from "../src/PositionsNFT.sol";
// import {StrategyAAVEV3UniswapV3Arbitrum} from "../src/StrategyAAVEV3UniswapV3Arbitrum.sol";

contract StrategyV1Test is Test {
    address arbitrumOracle_weth_usd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aArbWeth = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
    address aArbUsdt = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620;

    address uniswapV3SwapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    // PositionsNFT positions;

    // StrategyAAVEV3UniswapV3Arbitrum strategy;

    function setUp() public {
        // positions = new PositionsNFT();

        // Strategy_AAVEV3_UniswapV3.StrategyAAVEV3UniswapV3ConstructorArgs memory args = Strategy_AAVEV3_UniswapV3.StrategyAAVEV3UniswapV3ConstructorArgs({
        //     oracleQuoteTokenPerFeeToken: arbitrumOracle_weth_usd,
        //     oracleQuoteTokenPerBaseToken: arbitrumOracle_weth_usd,
        //     feeToken: weth,
        //     baseToken: weth,
        //     quoteToken: usdt,
        //     aaveV3Pool: aaveV3Pool,
        //     aaveV3ABaseToken: aArbWeth,
        //     aaveV3AQuoteToken: aArbUsdt,
        //     uniswapV3SwapRouter:uniswapV3SwapRouter
        // });
        // strategy = new Strategy_AAVEV3_UniswapV3(
        //     address(positions),
        //     0,
        //     args
        // );
    }

    function test_swap() public {}

    function test_() public {}
}
