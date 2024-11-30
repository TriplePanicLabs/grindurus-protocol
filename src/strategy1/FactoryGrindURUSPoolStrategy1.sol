// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IFactoryGrindURUSPoolStrategy} from "src/interfaces/IFactoryGrindURUSPoolStrategy.sol";
import {IGrindURUSPoolsNFT} from "src/interfaces/IGrindURUSPoolsNFT.sol";
import {GrindURUSPoolStrategy1, IGrindURUSPoolStrategy, IToken} from "src/strategy1/GrindURUSPoolStrategy1.sol";

/// @title FactoryGrindURUSPoolStrategy1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of strategyV1
contract FactoryGrindURUSPoolStrategy1 is IFactoryGrindURUSPoolStrategy {
    /// @dev address of grindurus pools NFT
    IGrindURUSPoolsNFT public grindurusPoolsNFT;

    /// @dev default config for strategyV1
    IGrindURUSPoolStrategy.Config public defaultConfig;

    // address public oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    // address public wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    // address public usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address public aaveV3PoolArbitrum =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    address public uniswapV3SwapRouterArbitrum =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 public uniswapV3PoolFeeArbitrum = 500;

    constructor(address _grindurusPoolsNFT) {
        if (_grindurusPoolsNFT != address(0)) {
            grindurusPoolsNFT = IGrindURUSPoolsNFT(_grindurusPoolsNFT);
        } else {
            grindurusPoolsNFT = IGrindURUSPoolsNFT(msg.sender);
        }
        defaultConfig = IGrindURUSPoolStrategy.Config({
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

    /// @notice checks that msg.sender is grindurusPoolsNFT
    function _onlyGrindURUSPoolsNFT() private view {
        if (msg.sender != address(grindurusPoolsNFT)) {
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
        address baseToken,
        address quoteToken
    ) public override returns (address pool) {
        _onlyGrindURUSPoolsNFT();
        IGrindURUSPoolStrategy.StrategyConstructorArgs
            memory strategyConstructorArgs = IGrindURUSPoolStrategy
                .StrategyConstructorArgs({
                    oracleQuoteTokenPerFeeToken: oracleQuoteTokenPerFeeToken,
                    oracleQuoteTokenPerBaseToken: oracleQuoteTokenPerBaseToken,
                    feeToken: feeToken,
                    baseToken: baseToken,
                    quoteToken: quoteToken,
                    lendingArgs: abi.encode(aaveV3PoolArbitrum),
                    dexArgs: abi.encode(
                        uniswapV3SwapRouterArbitrum,
                        uniswapV3PoolFeeArbitrum
                    )
                });
        GrindURUSPoolStrategy1 grindURUSPoolStrategy1 = new GrindURUSPoolStrategy1();
        grindURUSPoolStrategy1.initStrategy(
            address(grindurusPoolsNFT),
            poolId,
            strategyConstructorArgs,
            defaultConfig
        );
        pool = address(grindURUSPoolStrategy1);
        uint256 poolStrategyId = grindURUSPoolStrategy1.strategyId();
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
