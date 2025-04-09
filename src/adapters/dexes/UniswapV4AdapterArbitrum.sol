// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "src/interfaces/IDexAdapter.sol";
import {IUniswapV4SwapRouterArbitrum} from "src/interfaces/uniswapV4/IUniswapV4SwapRouterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title UniswapV3AdapterBase
/// @notice Adapter for UniswapV4
/// @dev adapter to UniswapV4 that inherrits by Strategy. Made for Arbitrum network
contract UniswapV4AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of swapRouter
    IUniswapV4SwapRouterArbitrum public swapRouter;

    /// @notice fee of uniswapV4 pool
    uint24 public fee;

    constructor() {}

    /// @notice initialize dex
    /// @param args encoded params
    function initDex(
        bytes memory args
    ) public {
        if (address(swapRouter) != address(0)) {
            revert DexInitialized();
        }
        (address _swapRouter, uint24 _fee, address _quoteToken, address _baseToken) = decodeDexConstructorArgs(args);

        if (_quoteToken != address(0)) {
            IToken(_quoteToken).forceApprove(_swapRouter, type(uint256).max);
        }
        if (_baseToken != address(0)) {
            IToken(_baseToken).forceApprove(_swapRouter, type(uint256).max);
        }

        swapRouter = IUniswapV4SwapRouterArbitrum(_swapRouter);
        fee = _fee;
    }

    /// @notice encode dex constructor args
    /// @param _swapRouter address of UniswapV4 pool manager
    /// @param _fee address of UniswapV3 pool fee
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    function encodeDexConstructorArgs(
        address _swapRouter,
        uint24 _fee,
        address _quoteToken,
        address _baseToken
    ) public pure returns (bytes memory) {
        return abi.encode(_swapRouter, _fee, _quoteToken, _baseToken);
    }

    /// @notice decode dex constructor args
    /// @param args encoded args of constructor via `encodeDexConstructorArgs`
    function decodeDexConstructorArgs(
        bytes memory args
    ) public pure returns (address _swapRouter, uint24 _fee, address _quoteToken, address _baseToken) {
        (_swapRouter, _fee, _quoteToken, _baseToken) = abi.decode(args, (address, uint24, address, address));
    }

    function _onlyAgent() internal view virtual {}

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
        // TODO implement swap on UniswapV4
    }

    /// @notice gets quote token
    /// @dev should be reimplemented in inherrited contract
    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    /// @notice gets base token
    /// @dev should be reimplemented in inherrited contract
    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }
}