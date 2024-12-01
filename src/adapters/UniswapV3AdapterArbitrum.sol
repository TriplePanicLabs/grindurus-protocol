// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "../interfaces/IDexAdapter.sol";
import {ISwapRouterArbitrum} from "../interfaces/uniswapV3/ISwapRouterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev adapter to UniswapV3 that inherrits by Strategy. Made for Arbitrum
contract UniswapV3AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of swapRouter
    ISwapRouterArbitrum public swapRouter;

    /// @notice fee of uniswapV3 pool
    uint24 public fee;

    constructor() {}

    function initDex(address baseToken, address quoteToken, bytes memory args) public {
        if (address(swapRouter) != address(0)) {
            revert DexInitialized();
        }
        (address _swapRouter, uint24 _fee) = decodeDexConstructorArgs(args);

        // infinite approve for transferFrom Uniswap
        IToken(baseToken).forceApprove(_swapRouter, type(uint256).max);
        IToken(quoteToken).forceApprove(_swapRouter, type(uint256).max);

        swapRouter = ISwapRouterArbitrum(_swapRouter);
        fee = _fee;
    }

    function encodeDexConstructorArgs(address _swapRouter, uint24 _fee) public pure returns (bytes memory) {
        return abi.encode(_swapRouter, _fee);
    }

    function decodeDexConstructorArgs(bytes memory args) public pure returns (address _swapRouter, uint24 _fee) {
        (_swapRouter, _fee) = abi.decode(args, (address, uint24));
    }

    function _onlyOwner() internal view virtual {}

    /// @notice set swap router
    function setUniSwapRouter(address _swapRouter) public {
        _onlyOwner();
        getBaseToken().forceApprove(address(swapRouter), 0);
        getQuoteToken().forceApprove(address(swapRouter), 0);
        swapRouter = ISwapRouterArbitrum(_swapRouter);
        getBaseToken().forceApprove(address(swapRouter), type(uint256).max);
        getQuoteToken().forceApprove(address(swapRouter), type(uint256).max);
    }

    /// @notice set fee
    function setUniFee(uint24 _fee) public {
        _onlyOwner();
        fee = _fee;
    }

    /// @notice swaps assets
    function swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) public override returns (uint256 amountOut) {
        uint256 tokenOutBalanceBefore = tokenOut.balanceOf(address(this));
        ISwapRouterArbitrum.ExactInputSingleParams memory params = ISwapRouterArbitrum.ExactInputSingleParams({
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

    /// @notice get base token
    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    /// @notice get quote token
    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    function _distributeTradeProfit(IToken token, uint256 profit) internal virtual {}
}
