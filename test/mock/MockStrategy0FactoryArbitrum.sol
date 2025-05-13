// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {Strategy0FactoryArbitrum} from "src/strategies/arbitrum/strategy0/Strategy0FactoryArbitrum.sol";

contract MockStrategy0FactoryArbitrum is Strategy0FactoryArbitrum {

    constructor (address _poolsNFT, address _registry, address mockSwapRouter) Strategy0FactoryArbitrum(_poolsNFT, _registry, address(0)) {
        uniswapV3SwapRouterArbitrum = mockSwapRouter;
    }
    
}