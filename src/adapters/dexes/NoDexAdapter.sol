// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "src/interfaces/IDexAdapter.sol";
import {ISwapRouterArbitrum} from "src/interfaces/uniswapV3/ISwapRouterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title NoDexAdapter
/// @notice Empty adapter for DEX
contract NoDexAdapter is IDexAdapter {
    using SafeERC20 for IToken;

    constructor() {}

    /// @notice constructor of initDex
    /// @param args no dex args
    function initDex(
        bytes memory args
    ) public pure {
        args;
    }

    function encodeDexConstructorArgs() public pure returns (bytes memory) {
        return abi.encode("");
    }

    function decodeDexConstructorArgs(
        bytes memory args
    ) public pure returns (string memory arg) {
        (arg) = abi.decode(args, (string));
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
        tokenIn; tokenOut; amountIn; amountOut;
    }

    function _distributeTradeProfit(
        IToken token,
        uint256 profit
    ) internal virtual {}
}
