// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {Registry, PriceOracleInverse} from "./Registry.sol";

/// @title RegistryBase
/// @dev stores array of strategy ids, strategy pairs, quote tokens, base tokens, and bounded oracles
contract RegistryBase is Registry {

    address public oracleWethUsdBase;

    address public wethBase;
    address public usdcBase;

    /// @param _poolsNFT address of poolsNFT
    constructor(address _poolsNFT) Registry(_poolsNFT) {
        oracleWethUsdBase = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // chainlink WETH/USD oracle;

        wethBase = 0x4200000000000000000000000000000000000006;
        usdcBase = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        
        oracles[usdcBase][wethBase] = oracleWethUsdBase;
        PriceOracleInverse priceOracleInverse = new PriceOracleInverse(oracleWethUsdBase);
        oracles[wethBase][usdcBase] = address(priceOracleInverse);
        
        quoteTokens.push(usdcBase);
        quoteTokens.push(wethBase);
        
        baseTokens.push(wethBase);
        baseTokens.push(usdcBase);
        
        quoteTokenIndex[usdcBase] = 0;
        quoteTokenIndex[wethBase] = 1;

        baseTokenIndex[wethBase] = 0;
        baseTokenIndex[usdcBase] = 1;

        quoteTokenCoherence[usdcBase]++;
        quoteTokenCoherence[wethBase]++;

        baseTokenCoherence[wethBase]++;
        baseTokenCoherence[usdcBase]++;


    }

}