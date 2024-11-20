// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "../interfaces/IDexAdapter.sol";
import {ISwapRouter} from "../interfaces/uniswapV3/ISwapRouter.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev adapter to UniswapV3 that inherrits by Strategy. Made for Arbitrum
contract UniswapV3AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of swapRouter
    ISwapRouter public swapRouter;

    /// @notice fee of uniswapV3 pool
    uint24 public fee;

    constructor(address baseToken, address quoteToken, bytes memory args) {
        (address _swapRouter, uint24 _fee) = decodeDexConstructorArgs(args);

        // infinite approve for transferFrom uniswap
        IToken(baseToken).forceApprove(_swapRouter, type(uint256).max);
        IToken(quoteToken).forceApprove(_swapRouter, type(uint256).max);

        swapRouter = ISwapRouter(_swapRouter);
        fee = _fee;
    }

    function encodeDexConstructorArgs(address _swapRouter, uint24 _fee) public pure returns (bytes memory) {
        return abi.encode(_swapRouter, _fee);
    }

    function decodeDexConstructorArgs(bytes memory args) public pure returns (address _swapRouter, uint24 _fee) {
        (_swapRouter, _fee) = abi.decode(args, (address, uint24));
    }

    function _onlyOwner() internal view virtual {}

    function setDexData(address _swapRouter, uint24 _fee) public {
        _onlyOwner();
        IToken baseToken = getBaseToken();
        IToken quoteToken = getQuoteToken();
        baseToken.forceApprove(address(swapRouter), 0);
        quoteToken.forceApprove(address(swapRouter), 0);
        swapRouter = ISwapRouter(_swapRouter);
        baseToken.forceApprove(address(swapRouter), type(uint256).max);
        quoteToken.forceApprove(address(swapRouter), type(uint256).max);
        fee = _fee;
    }

    function swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) public override returns (uint256 amountOut) {
        uint256 tokenOutBalanceBefore = tokenOut.balanceOf(address(this));
        ISwapRouter.ExactInputSingleParamsArbitrum memory params = ISwapRouter.ExactInputSingleParamsArbitrum({
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

    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    function _distributeTradeProfit(IToken token, uint256 profit) internal virtual {}
}
