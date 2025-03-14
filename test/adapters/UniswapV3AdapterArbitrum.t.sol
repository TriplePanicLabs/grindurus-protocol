// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3AdapterArbitrum, IToken} from "../../src/adapters/dexes/UniswapV3AdapterArbitrum.sol";

contract TestUniswapV3AdapterArbitrum is UniswapV3AdapterArbitrum {
    function swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        amountOut = _swap(tokenIn, tokenOut, amountIn);
    }
}

// $ forge test --match-path test/adapters/UniswapV3AdapterArbitrum.t.sol -vvv
contract UniswapV3AdapterArbitrumTest is Test {
    address arbitrumOracle_weth_usd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address uniswapV3SwapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 fee = 500;

    IToken public baseToken;

    IToken public quoteToken;

    TestUniswapV3AdapterArbitrum public adapter;

    function setUp() public {
        vm.createSelectFork("arbitrum");

        baseToken = IToken(wethArbitrum);
        quoteToken = IToken(usdtArbitrum);
        adapter = new TestUniswapV3AdapterArbitrum();
        
        bytes memory dexConstructorArgs = adapter.encodeDexConstructorArgs(uniswapV3SwapRouter, fee, usdtArbitrum, wethArbitrum);
        adapter.initDex(dexConstructorArgs);
    }

    function test_swap_baseToken_to_quoteToken() public {
        deal(address(baseToken), address(adapter), 1000e18);

        uint256 baseTokenAmount = 2e18;
        uint256 amountOut = adapter.swap(baseToken, quoteToken, baseTokenAmount);
        assert(amountOut > 0);
    }
}
