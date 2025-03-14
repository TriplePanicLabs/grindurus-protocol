// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "src/interfaces/IDexAdapter.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AerodromeAdapterBase is IDexAdapter {
    using SafeERC20 for IToken;

    function _swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {

    }

}