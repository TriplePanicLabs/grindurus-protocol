// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";

interface IDexAdapter {
    error DexInitialized();

    function swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) external returns (uint256 amountOut);
}
