// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { Registry, PriceOracleInverse } from "./Registry.sol";

/// @title RegistryArbitrum
/// @dev stores array of strategy ids, strategy pairs, quote tokens, base tokens, and bounded oracles
contract RegistryArbitrum is Registry {

    address public oracleWethUsdArbitrum;

    address public wethArbitrum;
    address public usdtArbitrum;
    address public usdcArbitrum;

    /// @param _poolsNFT address of poolsNFT
    constructor(address _poolsNFT) Registry(_poolsNFT) {
        oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

        wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        oracles[usdtArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
        oracles[usdcArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
        PriceOracleInverse priceOracleInverse = new PriceOracleInverse(oracleWethUsdArbitrum);
        oracles[wethArbitrum][usdtArbitrum] = address(priceOracleInverse);
        oracles[wethArbitrum][usdcArbitrum] = address(priceOracleInverse);
        
        quoteTokens.push(usdtArbitrum);
        quoteTokens.push(usdcArbitrum);
        quoteTokens.push(wethArbitrum);
        
        baseTokens.push(wethArbitrum);
        baseTokens.push(usdtArbitrum);
        baseTokens.push(usdcArbitrum);
        
        quoteTokenIndex[usdtArbitrum] = 0;
        quoteTokenIndex[usdcArbitrum] = 1;
        quoteTokenIndex[wethArbitrum] = 2;

        baseTokenIndex[wethArbitrum] = 0;
        baseTokenIndex[usdtArbitrum] = 1;
        baseTokenIndex[usdcArbitrum] = 2;

        quoteTokenCoherence[usdtArbitrum]++;
        quoteTokenCoherence[usdcArbitrum]++;
        quoteTokenCoherence[wethArbitrum]++;

        baseTokenCoherence[wethArbitrum]++;
        baseTokenCoherence[usdtArbitrum]++;
        baseTokenCoherence[usdcArbitrum]++;

    }

}