// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IDexAdapter, IToken } from "src/interfaces/IDexAdapter.sol";
import { ISwapRouterArbitrum } from "src/interfaces/uniswapV3/arbitrum/ISwapRouterArbitrum.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title UniswapV3AdapterArbitrum
/// @notice Adapter for UniswapV3
/// @dev adapter to UniswapV3 that inherrits by Strategy. Made for Arbitrum network
contract UniswapV3AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of swapRouter
    ISwapRouterArbitrum public swapRouter;

    /// @notice fee of uniswapV3 pool
    uint24 public uniswapV3PoolFee;

    constructor() {}

    /// @notice initialize dex
    /// @param args encoded params
    function initDex(
        bytes memory args
    ) public {
        if (address(swapRouter) != address(0)) {
            revert DexInitialized();
        }
        (address _swapRouter, uint24 _uniswapV3PoolFee, address _baseToken, address _quoteToken) = decodeDexConstructorArgs(args);

        // infinite approve for transferFrom Uniswap
        IToken(_baseToken).forceApprove(_swapRouter, type(uint256).max);
        IToken(_quoteToken).forceApprove(_swapRouter, type(uint256).max);

        swapRouter = ISwapRouterArbitrum(_swapRouter);
        uniswapV3PoolFee = _uniswapV3PoolFee;
    }

    /// @notice encode dex constructor args
    /// @param _swapRouter address of UniswapV3 swap routers
    /// @param _uniswapV3PoolFee address of UniswapV3 pool fee
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    function encodeDexConstructorArgs(
        address _swapRouter,
        uint24 _uniswapV3PoolFee,
        address _baseToken,
        address _quoteToken
    ) public pure returns (bytes memory) {
        return abi.encode(_swapRouter, _uniswapV3PoolFee, _baseToken, _quoteToken);
    }

    /// @notice decode dex constructor args
    /// @param args encoded args of constructor via `encodeDexConstructorArgs`
    function decodeDexConstructorArgs(
        bytes memory args
    ) public pure returns (address _swapRouter, uint24 _uniswapV3PoolFee, address _baseToken, address _quoteToken) {
        (_swapRouter, _uniswapV3PoolFee, _baseToken, _quoteToken) = abi.decode(args, (address, uint24, address, address));
    }

    /// @notice gets dex params
    function getDexParams() public view virtual override returns (bytes memory args) {
        args = encodeDexConstructorArgs(address(swapRouter), uniswapV3PoolFee, address(getBaseToken()), address(getQuoteToken()));
    }

    /// @notice sets dex params
    /// @param args encoded dex params
    function setDexParams(bytes memory args) public virtual override {
        (
            address _swapRouter,
            uint24 _uniswapV3PoolFee,
            /** address _quoteToken*/,
            /** address _baseToken*/
        ) = decodeDexConstructorArgs(args);
        
        getBaseToken().forceApprove(address(swapRouter), 0);
        getQuoteToken().forceApprove(address(swapRouter), 0);
        swapRouter = ISwapRouterArbitrum(_swapRouter);
        getBaseToken().forceApprove(address(swapRouter), type(uint256).max);
        getQuoteToken().forceApprove(address(swapRouter), type(uint256).max);
        uniswapV3PoolFee = _uniswapV3PoolFee;
    }

    /// @notice swaps assets
    /// @param tokenIn address of tokenIn
    /// @param tokenOut address of token out
    /// @param amountIn amount of tokenIn
    /// @return amountOut amount of tokenOut
    function _swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) internal virtual returns (uint256 amountOut) {
        uint256 tokenOutBalanceBefore = tokenOut.balanceOf(address(this));
        ISwapRouterArbitrum.ExactInputSingleParams
            memory params = ISwapRouterArbitrum.ExactInputSingleParams({
                tokenIn: address(tokenIn),
                tokenOut: address(tokenOut),
                fee: uniswapV3PoolFee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0, // any amount
                sqrtPriceLimitX96: 0
            });
        swapRouter.exactInputSingle(params);
        uint256 tokenOutBalanceAfter = tokenOut.balanceOf(address(this));
        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
    }

    /// @notice gets base token
    /// @dev should be reimplemented in inherrited contract
    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    /// @notice gets quote token
    /// @dev should be reimplemented in inherrited contract
    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

}
