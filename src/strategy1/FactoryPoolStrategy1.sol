// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IFactoryPoolStrategy} from "src/interfaces/IFactoryPoolStrategy.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {PoolStrategy1, IPoolStrategy, IToken} from "src/strategy1/PoolStrategy1.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of strategyV1
contract FactoryPoolStrategy1 is IFactoryPoolStrategy {
    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IPoolStrategy.Config public defaultConfig;

    // address public oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    // address public wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    // address public usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address public aaveV3PoolArbitrum =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    address public uniswapV3SwapRouterArbitrum =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 public uniswapV3PoolFeeArbitrum = 500;

    constructor(address _poolsNFT) {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT = IPoolsNFT(msg.sender);
        }
        defaultConfig = IPoolStrategy.Config({
            // maxLiquidity = initLiquidity * (extraCoef + 1) ** (longNumberMax - 1)
            longNumberMax: 4,
            hedgeNumberMax: 4,
            averagePriceVolatility: 30 * (10 ** 8),
            extraCoef: 2_00, // x2.00
            returnPercentLongSell: 100_50, // 100.50% // returnPercent = (amountInvested + profit) * 100 / amountInvested
            returnPercentHedgeSell: 100_50, // 100.50%
            returnPercentHedgeRebuy: 100_50 // 100.50%
        });
    }

    /// @notice checks that msg.sender is poolsNFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != address(poolsNFT)) {
            revert NotGrindurusPoolsNFT();
        }
    }

    /// @notice deploy strategy pool
    /// @param poolId id of pool
    /// @param oracleQuoteTokenPerFeeToken oracle address
    /// @param oracleQuoteTokenPerBaseToken oracle address
    /// @param feeToken address of fee token (ETH)
    /// @param baseToken address of base token
    /// @param quoteToken address of quote token
    /// @return pool address of pool
    function deploy(
        uint256 poolId,
        address oracleQuoteTokenPerFeeToken,
        address oracleQuoteTokenPerBaseToken,
        address feeToken,
        address quoteToken,
        address baseToken
    ) public override returns (address pool) {
        _onlyPoolsNFT();
        PoolStrategy1 poolStrategy1 = new PoolStrategy1();
        poolStrategy1.init(
            address(poolsNFT),
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            quoteToken,
            baseToken,
            abi.encode(aaveV3PoolArbitrum),
            abi.encode(
                uniswapV3SwapRouterArbitrum,
                uniswapV3PoolFeeArbitrum
            ),
            defaultConfig
        );
        pool = address(poolStrategy1);
        uint256 poolStrategyId = poolStrategy1.strategyId();
        uint256 factoryStrategyId = strategyId();
        if (poolStrategyId != factoryStrategyId) {
            revert InvalidStrategyId(poolStrategyId, factoryStrategyId);
        }
    }

    /// @notice returns strategy id of factory
    function strategyId() public pure override returns (uint16) {
        return 1;
    }
}
