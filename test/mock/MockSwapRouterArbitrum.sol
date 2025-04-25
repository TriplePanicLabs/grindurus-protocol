// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {IToken} from 'src/interfaces/IToken.sol';
import {ISwapRouterArbitrum} from 'src/interfaces/uniswapV3/arbitrum/ISwapRouterArbitrum.sol';
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockSwapRouterArbitrum is ISwapRouterArbitrum {
    using SafeERC20 for IToken;

    uint256 public rateTokenInByTokenOut;

    uint8 public rateDecimals;

    constructor() {
        rateDecimals = 8;
        rateTokenInByTokenOut = 3000 * 10 ** rateDecimals;
    }

    function setRate(uint256 _rateTokenInByTokenOut) public {
        rateTokenInByTokenOut = _rateTokenInByTokenOut;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external override payable returns (uint256 amountOut) {
        IToken tokenIn = IToken(params.tokenIn); // usdt
        IToken tokenOut = IToken(params.tokenOut); // weth
        uint8 tokenInDecimals = tokenIn.decimals(); // 
        uint8 tokenOutDecimals = tokenOut.decimals();
        if (address(tokenIn) == 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9) { // usdt
            amountOut = params.amountIn * (10 ** (tokenOutDecimals - tokenInDecimals + rateDecimals)) / rateTokenInByTokenOut ;
        } else {
            // in = weth , decimals = 18
            // out = usdt , decimals = 6
            amountOut = params.amountIn * rateTokenInByTokenOut / (10 ** (tokenInDecimals - tokenOutDecimals + rateDecimals)) ;
        }
        tokenOut.transfer(params.recipient, amountOut);
    }

}