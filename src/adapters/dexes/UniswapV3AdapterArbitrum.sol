// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "../../interfaces/IDexAdapter.sol";
import {ISwapRouterArbitrum} from "../../interfaces/uniswapV3/ISwapRouterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title UniswapV3AdapterArbitrum
/// @notice Adapter for UniswapV3
/// @dev adapter to UniswapV3 that inherrits by Strategy. Made for Arbitrum network
contract UniswapV3AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of swapRouter
    ISwapRouterArbitrum public swapRouter;

    /// @notice fee of uniswapV3 pool
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

        // infinite approve for transferFrom Uniswap
        IToken(_quoteToken).forceApprove(_swapRouter, type(uint256).max);
        IToken(_baseToken).forceApprove(_swapRouter, type(uint256).max);

        swapRouter = ISwapRouterArbitrum(_swapRouter);
        fee = _fee;
    }

    /// @notice encode dex constructor args
    /// @param _swapRouter address of UniswapV3 swap routers
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

    function _onlyOwner() internal view virtual {}

    /// @notice set swap router
    function setSwapRouter(address _swapRouter) public {
        _onlyOwner();
        getBaseToken().forceApprove(address(swapRouter), 0);
        getQuoteToken().forceApprove(address(swapRouter), 0);
        swapRouter = ISwapRouterArbitrum(_swapRouter);
        getBaseToken().forceApprove(address(swapRouter), type(uint256).max);
        getQuoteToken().forceApprove(address(swapRouter), type(uint256).max);
    }

    /// @notice set fee
    /// @param _fee fee for uniswapV3 pool
    function setFee(uint24 _fee) public {
        _onlyOwner();
        fee = _fee;
    }

    /// @notice swap
    /// @dev revert due to security. Can be inherrited and reimplemented
    /// @param tokenIn address of token to be swapped from
    /// @param tokenOut address of token to be swapped to
    /// @param amountIn amount of tokenIn to be swapped
    function swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) public virtual override returns (uint256 amountOut) {
        tokenIn; tokenOut; amountIn; amountOut;
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        revert(); // no direct swap
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
                fee: fee,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0, // any amount
                sqrtPriceLimitX96: 0
            });
        swapRouter.exactInputSingle(params);
        uint256 tokenOutBalanceAfter = tokenOut.balanceOf(address(this));
        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
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
