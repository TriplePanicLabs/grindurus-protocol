// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3AdapterBase, IToken} from "src/adapters/dexes/UniswapV3AdapterBase.sol";

contract TestUniswapV3AdapterBase is UniswapV3AdapterBase {
    function swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        amountOut = _swap(tokenIn, tokenOut, amountIn);
    }
}

// $ forge test --match-path test/adapters/UniswapV3AdapterBase.t.sol -vvv
contract UniswapV3AdapterBaseTest is Test {
    address arbitrumOracle_weth_usd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethBase = 0x4200000000000000000000000000000000000006;
    address usdcBase = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    address uniswapV3SwapRouter = 0x2626664c2603336E57B271c5C0b26F421741e481;
    uint24 uniswapV3PoolFee = 500;

    IToken public baseToken;

    IToken public quoteToken;

    TestUniswapV3AdapterBase public adapter;

    function setUp() public {
        vm.createSelectFork("base");

        baseToken = IToken(wethBase);
        quoteToken = IToken(usdcBase);
        adapter = new TestUniswapV3AdapterBase();
        
        bytes memory dexConstructorArgs = adapter.encodeDexConstructorArgs(uniswapV3SwapRouter, uniswapV3PoolFee, usdcBase, wethBase);
        adapter.initDex(dexConstructorArgs);
    }

    function test_swap_baseToken_to_quoteToken() public {
        deal(address(baseToken), address(adapter), 1000e18);

        uint256 baseTokenAmount = 2e18;
        uint256 amountOut = adapter.swap(baseToken, quoteToken, baseTokenAmount);
        assert(amountOut > 0);
    }
}
