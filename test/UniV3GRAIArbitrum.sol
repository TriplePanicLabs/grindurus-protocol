// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console} from "forge-std/Test.sol";
import { IToken } from "src/interfaces/IToken.sol";
import { IUniswapV3Pool } from "src/interfaces/uniswapV3/arbitrum/IUniswapV3Pool.sol";
import { ISwapRouterArbitrum } from "src/interfaces/uniswapV3/arbitrum/ISwapRouterArbitrum.sol";
import { IUniswapV3Factory } from "src/interfaces/uniswapV3/arbitrum/IUniswapV3Factory.sol";
import { INonfungiblePositionManager } from "src/interfaces/uniswapV3/arbitrum/INonfungiblePositionManager.sol";

// $ forge test --match-path test/UniV3GRAIArbitrum.sol -vvv
contract UniV3GRAIArbitrumTest is Test {
    IToken public grai;
    IToken public weth;
    IUniswapV3Factory public factory;
    INonfungiblePositionManager public positionManager;
    ISwapRouterArbitrum public router;
    IUniswapV3Pool public pool;

    address public constant FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant ROUTER_ADDRESS = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address public constant NON_FUNGIBLE_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant GRAI_ADDRESS = 0x2cd392CC10887a258019143a710a5Ce2C5B5d88d;
    uint256 public tokenId;
    
    uint24 public constant POOL_FEE = 100; // 0.01%

    function setUp() public {
        vm.createSelectFork("arbitrum");

        factory = IUniswapV3Factory(FACTORY_ADDRESS);
        positionManager = INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER);
        router = ISwapRouterArbitrum(ROUTER_ADDRESS);
        grai = IToken(GRAI_ADDRESS);
        weth = IToken(WETH_ADDRESS);
        address token0;
        address token1;

        address poolAddress = factory.getPool(GRAI_ADDRESS, WETH_ADDRESS, POOL_FEE);
        if (poolAddress == address(0)) {
            poolAddress = factory.createPool(GRAI_ADDRESS, WETH_ADDRESS, POOL_FEE);
        }
        pool = IUniswapV3Pool(poolAddress);
        
        uint160 sqrtPriceX96;
        if (GRAI_ADDRESS < WETH_ADDRESS) {
            token0 = GRAI_ADDRESS;
            token1 = WETH_ADDRESS;

            // 100500 grAI = 0.001 WETH → price = 0.001 token1/ 100500 token0 = 0.000000009950248756
            sqrtPriceX96 = uint160(sqrt(9.950248756e-9 * 1e18) * 2**96 / 1e9); // sqrt of price in Q64.96
        } else {
            token0 = WETH_ADDRESS;
            token1 = GRAI_ADDRESS;

            // 100500 grAI = 0.001 WETH → price = 100500 token1/ 0.001 token0 = 100500000
            sqrtPriceX96 = uint160(sqrt(100500000 * 1e18) * 2**96 / 1e9); // sqrt of price in Q64.96
        }

        pool.initialize(sqrtPriceX96);

        deal(GRAI_ADDRESS, address(this), 100500 * 1e18);
        deal(WETH_ADDRESS, address(this), 0.001 ether);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: GRAI_ADDRESS,
            token1: WETH_ADDRESS,
            fee: POOL_FEE,
            tickLower: -887220,  // Represents price range lower bound
            tickUpper: 887220,   // Represents price range upper bound
            amount0Desired: 100500 * 1e18,  // Amount of GRAI
            amount1Desired: 0.001 * 1e18,   // Amount of WETH
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 15
        });

        grai.approve(NON_FUNGIBLE_POSITION_MANAGER, 100500 * 1e18);
        weth.approve(NON_FUNGIBLE_POSITION_MANAGER, 0.001 * 1e18);

        (uint256 _tokenId, , ,) = positionManager.mint(params);
        tokenId = _tokenId;
    }

    function testSwapGRAIForWETH() public {

        uint256 amountIn = 1 * 1e18; // 1 grAI
        deal(GRAI_ADDRESS, address(this), amountIn);

        uint256 graiBalanceBefore = grai.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));

        ISwapRouterArbitrum.ExactInputSingleParams memory params = ISwapRouterArbitrum.ExactInputSingleParams({
            tokenIn: GRAI_ADDRESS,
            tokenOut: WETH_ADDRESS,
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        grai.approve(address(router), amountIn);
        uint256 amountOut = router.exactInputSingle(params);

        uint256 graiBalanceAfter = grai.balanceOf(address(this));
        uint256 wethBalanceAfter = weth.balanceOf(address(this));

        assertEq(graiBalanceBefore - graiBalanceAfter, amountIn, "Incorrect GRAI amount spent");
        assertEq(wethBalanceAfter - wethBalanceBefore, amountOut, "Incorrect WETH amount received");
        assertTrue(amountOut > 0, "Swap failed");
    }

    function test_increaseLiquidity() public {        
        uint256 graiAmount = 100 * 1e18;
        uint256 wethAmount = 1 * 1e18;

        deal(GRAI_ADDRESS, address(this), graiAmount);
        deal(WETH_ADDRESS, address(this), wethAmount);

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: graiAmount,
            amount1Desired: wethAmount,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 15
        });

        grai.approve(NON_FUNGIBLE_POSITION_MANAGER, type(uint256).max);
        weth.approve(NON_FUNGIBLE_POSITION_MANAGER, type(uint256).max);

        uint256 graiAmountBefore = grai.balanceOf(address(pool));
        uint256 wethAmountBefore = weth.balanceOf(address(pool));
        // console.log(graiAmount);
        // console.log(wethAmount);

        positionManager.increaseLiquidity(params);

        uint256 graiAmountAfter = grai.balanceOf(address(pool));
        uint256 wethAmountAfter = weth.balanceOf(address(pool));
        // console.log(graiAmount);
        // console.log(wethAmount);

        assertEq(graiAmountAfter - graiAmountBefore, graiAmount, "Incorrect GRAI amount added as liquidity");
        assertGt(wethAmountAfter, wethAmountBefore);

    }

    function testSwapWETHForGRAI() public {
        uint256 amountIn = 1 * 1e18; // 1 WETH
        deal(WETH_ADDRESS, address(this), amountIn);

        uint256 graiBalanceBefore = grai.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));

        ISwapRouterArbitrum.ExactInputSingleParams memory params = ISwapRouterArbitrum.ExactInputSingleParams({
            tokenIn: WETH_ADDRESS,
            tokenOut: GRAI_ADDRESS,
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        weth.approve(address(router), amountIn);
        uint256 amountOut = router.exactInputSingle(params);
        console.log("amountOut without transfer", amountOut);

        uint256 graiBalanceAfter = grai.balanceOf(address(this));
        uint256 wethBalanceAfter = weth.balanceOf(address(this));

        assertEq(wethBalanceBefore - wethBalanceAfter, amountIn, "Incorrect WETH amount spent");
        assertEq(graiBalanceAfter - graiBalanceBefore, amountOut, "Incorrect GRAI amount received");
        assertTrue(amountOut > 0, "Swap failed");
    }

    function test_swapWETHForGRAI_withTransfer() public {
        uint256 amountIn = 1 * 1e18; // 1 WETH
        deal(WETH_ADDRESS, address(this), 2 * amountIn);
        // deal(WETH_ADDRESS, address(this), amountIn);

        weth.transfer(address(pool), amountIn);

        uint256 graiBalanceBefore = grai.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));

        ISwapRouterArbitrum.ExactInputSingleParams memory params = ISwapRouterArbitrum.ExactInputSingleParams({
            tokenIn: WETH_ADDRESS,
            tokenOut: GRAI_ADDRESS,
            fee: POOL_FEE,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        weth.approve(address(router), amountIn);
        uint256 amountOut = router.exactInputSingle(params);
        console.log("amountOut with transfer", amountOut);

        uint256 graiBalanceAfter = grai.balanceOf(address(this));
        uint256 wethBalanceAfter = weth.balanceOf(address(this));

        assertEq(wethBalanceBefore - wethBalanceAfter, amountIn, "Incorrect WETH amount spent");
        assertEq(graiBalanceAfter - graiBalanceBefore, amountOut, "Incorrect GRAI amount received");
        assertTrue(amountOut > 0, "Swap failed");
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        // Approximate fixed-point square root
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}