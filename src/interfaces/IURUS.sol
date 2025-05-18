// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IToken } from "src/interfaces/IToken.sol";
import { IERC5313 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC5313.sol";
import { IOracle } from "src/interfaces/IOracle.sol";

interface IURUS is IERC5313 {

    error InvalidConfig();
    error InvalidOp();
    error NotLongNumberMax();
    error Longed();
    error NotLonged();
    error Hedged();
    error NotHedged();
    error BuyUpperPriceMin();
    error NotProfitableLongSell();
    error HedgeSellOutOfBound();
    error NotProfitableHedgeSell();
    error NotProfitableRebuy();

    event Transmute(
        uint8 op,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount,
        uint256 swapPrice,
        uint256 feeQty
    );

    /// @dev URUS OPerations
    enum Op {
        LONG_BUY, // 0
        LONG_SELL, // 1
        HEDGE_SELL, // 2
        HEDGE_REBUY // 3
    }

    struct FeeConfig {
        uint256 longSellFeeCoef; // [longSellFeeCoef] = (no dimension)
        uint256 hedgeSellFeeCoef; // [hedgeSellFeeCoef] = (no dimension)
        uint256 hedgeRebuyFeeCoef; // [hedgeRebuyFeeCoef] = (no dimension)
    }

    struct PnL {
        int256 longSellRealtime;
        int256 longSellTarget;
        int256 hedgeSellInitRealtime;
        int256 hedgeSellRealtime;
        int256 hedgeSellTarget;
        int256 hedgeRebuyRealtime;
        int256 hedgeRebuyTarget;
    }

    /**
    Possible values:
        longNumberMax = 3
        hedgeNumberMax = 3
        extraCoef = 2_00 // x2.00
        priceVolatilityPercent = 1_00 // 1%
        returnPercentLongSell = 100_50 // 100.5%
        returnPercentHedgeSell = 100_50 // 100.5%
        returnPercentHedgeRebuy = 100_50 // 100.5%
     */
    struct Config {
        uint8 longNumberMax; // [longNumberMax] = (no dimension)
        uint8 hedgeNumberMax; // [hedgeNumberMax] = (no dimension)
        uint256 extraCoef; // [extraCoef] = (no dimension)
        uint256 priceVolatilityPercent; // [priceVolatilityPercent] = %
        uint256 returnPercentLongSell; // [returnPercentLongSell] = %
        uint256 returnPercentHedgeSell; // [returnPercentHedgeSell] = %
        uint256 returnPercentHedgeRebuy; // [returnPercentHedgeRebuy] = %
    }

    struct Runtime {
        uint256 initLiquidity;
        uint256 liquidity;
        uint256 investCoef;
    }

    struct HelperData {
        // immutable data
        uint8 quoteTokenDecimals;
        uint8 baseTokenDecimals;
        uint8 feeTokenDecimals;
        uint8 oracleQuoteTokenPerBaseTokenDecimals;
        uint8 oracleQuoteTokenPerFeeTokenDecimals;
        uint256 oracleQuoteTokenPerBaseTokenMultiplier;
        uint256 oracleQuoteTokenPerFeeTokenMultiplier;
        uint256 coefMultiplier;
        uint256 percentMultiplier;
    }

    struct Position {
        uint8 number; // [number] = (no dimension)
        uint8 numberMax; // [numberMax] = (no dimension)
        uint256 priceMin; // [priceMin] = quoteToken/baseToken
        uint256 liquidity; // [liquidity] = quoteToken
        uint256 qty; // [qty] = baseToken
        uint256 price; // [price] = quoteToken/baseToken
        uint256 feeQty; // [feeQty] = feeToken
        uint256 feePrice; // [feePrice] = quoteToken/feeToken OR baseToken/feeToken
    }

    struct Profits {
        uint256 quoteTokenYieldProfit; // [quoteTokenYieldProfit] = quoteToken
        uint256 baseTokenYieldProfit; // [baseTokenYieldProfit] = baseToken
        uint256 quoteTokenTradeProfit; // [quoteTokenTradeProfit] = quoteToken
        uint256 baseTokenTradeProfit; // [baseTokenTradeProfit] = baseToken
    }

    function MIN_LONG_NUMBER_MAX() external view returns (uint8);

    function MIN_HEDGE_NUMBER_MAX() external view returns (uint8);

    function startTimestamp() external view returns (uint256);

    function oracleQuoteTokenPerFeeToken() external view returns (IOracle);

    function oracleQuoteTokenPerBaseToken() external view returns (IOracle);

    function feeToken() external view returns (IToken);

    function baseToken() external view returns (IToken);

    function quoteToken() external view returns(IToken);

    function evalMaxLiquidity() external view returns (uint256);

    function evalInvestCoef() external view returns (uint256 investCoef);

    function setOracles(address oracleQuoteTokenPerFeeToken, address oracleQuoteTokenPerBaseToken) external;

    function setConfig(Config memory conf) external;

    function setLongNumberMax(uint8 longNumberMax) external;

    function setHedgeNumberMax(uint8 hedgeNumberMax) external;

    function setExtraCoef(uint256 extraCoef) external;

    function setPriceVolatilityPercent(uint256 priceVolatilityPercent) external;

    function setOpReturnPercent(uint8 op, uint256 returnPercent) external;

    function setOpFeeCoef(uint8 op, uint256 feeCoef) external;

    function deposit(
        uint256 quoteTokenAmount
    ) external returns (uint256 depositedQuoteTokenAmount);

    function deposit2(
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) external returns (uint256 depositedBaseTokenAmount);

    function withdraw(
        address to,
        uint256 quoteTokenAmount
    ) external returns (uint256 withdrawnQuoteToken); 

    function withdraw2(
        address to,
        uint256 baseTokenAmount
    ) external returns (uint256 withdrawnBaseToken);

    function exit() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function long_buy() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function long_sell() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function hedge_sell() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function hedge_rebuy() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function microOps() external returns (bool iterated);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// PRICES

    function getPriceQuoteTokenPerBaseToken() external view returns (uint256 price);

    function getPriceQuoteTokenPerFeeToken() external view returns (uint256 price);

    function getPriceBaseTokenPerFeeToken(uint256 quoteTokenPerBaseTokenPrice) external view returns (uint256 price);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// CALCULATE FUNCTIONS

    function calcSwapPrice(
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    ) external view returns (uint256 price);

    function calcLongSellThreshold() external view
        returns (
            uint256 quoteTokenAmountThreshold,
            uint256 swapPriceThreshold
        );

    function calcTargetHedgePrice(
        uint8 hedgeNumber,
        uint256 priceMin,
        uint256 priceMax
    ) external view returns (uint256 targetPrice);

    function calcHedgeSellInitBounds() external view returns (uint256 thresholdHigh, uint256 thresholdLow);

    function calcHedgeSellThreshold(uint256 baseTokenAmount) external view
        returns (
            uint256 liquidity,
            uint256 quoteTokenAmountThreshold,
            uint256 targetPrice,
            uint256 swapPriceThreshold
        );

    function calcHedgeRebuyThreshold(uint256 quoteTokenAmount) external view
        returns (
            uint256 baseTokenAmountThreshold,
            uint256 hedgeLossInQuoteToken,
            uint256 hedgeLossInBaseToken,
            uint256 swapPriceThreshold
        );

    function calcHedgeSellThreshold() external view 
        returns (
            uint256 liquidity,
            uint256 quoteTokenAmountThreshold,
            uint256 targetPrice,
            uint256 swapPriceThreshold
        );

    function calcTargetHedgePrice() external view returns (uint256 targetPrice);

    function calcHedgeRebuyThreshold() external view
        returns (
            uint256 baseTokenAmountThreshold,
            uint256 hedgeLossInQuoteToken,
            uint256 hedgeLossInBaseToken,
            uint256 swapPriceThreshold
        );

    function calcQuoteTokenByBaseToken(
        uint256 baseTokenAmount, 
        uint256 quoteTokenPerBaseTokenPrice
    ) external view returns (uint256 quoteTokenAmount);

    function calcQuoteTokenByFeeToken(
        uint256 feeTokenAmount, 
        uint256 quoteTokenPerFeeTokenPrice
    ) external view returns (uint256 quoteTokenAmount);

    function calcBaseTokenByFeeToken(
        uint256 feeTokenAmount, 
        uint256 baseTokenPerFeeTokenPrice
    ) external view returns (uint256 baseTokenAmount);

    function getThresholds() external view 
        returns (
            uint256 longBuyPriceMin,
            uint256 longSellQuoteTokenAmountThreshold,
            uint256 longSellSwapPriceThreshold,
            uint256 hedgeSellInitPriceThresholdHigh,
            uint256 hedgeSellInitPriceThresholdLow,
            uint256 hedgeSellLiquidity,
            uint256 hedgeSellQuoteTokenAmountThreshold,
            uint256 hedgeSellTargetPrice,
            uint256 hedgeSellSwapPriceThreshold,
            uint256 hedgeRebuyBaseTokenAmountThreshold,
            uint256 hedgeRebuySwapPriceThreshold
        );

    function getPnL() external view returns (PnL memory);

    function getPnL(uint256 spotPrice) external view returns (PnL memory);

    function getLong()
        external
        view
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        );

    function getHedge()
        external
        view
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        );

    function isDrawdown() external view returns (bool);

    function getRuntime() external view returns (
        uint256 initLiquidity,
        uint256 liquidity,
        uint256 investCoef
    );

    function checkConfig(Config memory conf) external pure returns (bool);

    function getConfig()
        external
        view
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 extraCoef,
            uint256 priceVolatilityPercent,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        );

    function getFeeConfig()
        external
        view 
        returns(
            uint256 longSellFeeCoef,
            uint256 hedgeSellFeeCoef,
            uint256 hedgeRebuyFeeCoef
        );

    function getProfits()
        external
        view
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        );

    function getTotalProfits()
        external
        view
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        );

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}