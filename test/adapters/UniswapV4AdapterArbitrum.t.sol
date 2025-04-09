// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV4AdapterArbitrum, IToken} from "src/adapters/dexes/UniswapV4AdapterArbitrum.sol";

contract TestUniswapV4AdapterArbitrum is UniswapV4AdapterArbitrum {
    function swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        amountOut = _swap(tokenIn, tokenOut, amountIn);
    }
}

// $ forge test --match-path test/adapters/UniswapV4AdapterArbitrum.t.sol -vvv
contract UniswapV4AdapterArbitrumTest is Test {

    address wethArbitrum = address(0);
    address usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address poolManager = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
    uint24 fee = 100;

    IToken public baseToken;

    IToken public quoteToken;

    TestUniswapV4AdapterArbitrum public adapter;

    function setUp() public {
        vm.createSelectFork("arbitrum");

        baseToken = IToken(wethArbitrum);
        quoteToken = IToken(usdcArbitrum);
        adapter = new TestUniswapV4AdapterArbitrum();
        
        bytes memory dexConstructorArgs = adapter.encodeDexConstructorArgs(poolManager, fee, address(quoteToken), address(baseToken));
        adapter.initDex(dexConstructorArgs);
    }

    function test_swap_baseToken_to_quoteToken() public {
        deal(address(adapter), 1000e18);

        uint256 baseTokenAmount = 2e18;
        uint256 amountOut = adapter.swap(baseToken, quoteToken, baseTokenAmount);
        assert(amountOut > 0);
    }
}
