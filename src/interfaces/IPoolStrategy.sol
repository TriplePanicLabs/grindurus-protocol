// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";
import {IPoolsNFT} from "./IPoolsNFT.sol";
import {IERC5313} from "lib/openzeppelin-contracts/contracts/interfaces/IERC5313.sol"; // owner interface

/// @notice the interface for Strategy Pool
interface IPoolStrategy is IERC5313 {
    error StrategyInitialized();
    error InvalidConfig();
    error InvalidLongNumberMax();
    error InvalidHedgeNumberMax();
    error InvalidExtraCoef();
    error InvalidStrategyOpForFeeCoef();
    error InvalidStrategyOpForReturn();
    error InvalidReturnOfInvestment();
    error InvalidLength();
    error InvalidPriceVolatility();
    error NotQuoteToken();
    error NotOwner();
    error NotPoolsNFT();
    error QuoteTokenInvested();
    error LongNumberMax();
    error BuyUpperPriceMin(uint256 swapPrice, uint256 priceMin);
    error NoBuy();
    error NotProfitableLongSell();
    error HedgeSellOutOfBound(uint256 swapPrice, uint256 thresholdHigh, uint256 thresholdLow);
    error NotLongNumberMax();
    error DivestExceedsMaxLiquidity();
    error QuoteTokenAmountExceededMaxLiquidity();
    error NotProfitableHedgeSell();
    error Hedged();
    error NoHedge();
    error NotProfitableRebuy();
    error CantSweepYieldToken();
    error ZeroETH();
    error FailETHTransfer();
    error FailTokenTransfer();

    event LongBuy(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );
    event LongSell(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );
    event HedgeSell(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );
    event HedgeRebuy(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );

    /// @dev OPeration to number:
    ///     LONG_BUY == 0
    ///     LONG_SELL ==  1
    ///     HEDGE_SELL ==  2
    ///     HEDGE_REBUY ==  3
    ///     REBALANCE ==  4
    ///     INVEST ==  5
    ///     DIVEST ==  6
    enum StrategyOp {
        LONG_BUY, // 0
        LONG_SELL, // 1
        HEDGE_SELL, // 2
        HEDGE_REBUY, // 3
        REBALANCE, // 4
        INVEST, // 5
        DIVEST // 6

    }

    struct FeeConfig {
        uint256 longSellFeeCoef; // [longSellFeeCoef] = (no dimension)
        uint256 hedgeSellFeeCoef; // [hedgeSellFeeCoef] = (no dimension)
        uint256 hedgeRebuyFeeCoef; // [hedgeRebuyFeeCoef] = (no dimension)
    }

    struct Config {
        uint8 longNumberMax; // [longNumberMax] = (no dimension)
        uint8 hedgeNumberMax; // [hedgeNumberMax] = (no dimension)
        uint256 extraCoef; // [extraCoef] = (no dimension)
        uint256 averagePriceVolatility; // [averagePriceVolatility] = quoteToken / baseToken
        uint256 returnPercentLongSell; // [returnPercentLongSell] = %
        uint256 returnPercentHedgeSell; // [returnPercentHedgeSell] = %
        uint256 returnPercentHedgeRebuy; // [returnPercentHedgeRebuy] = %
    }

    struct HelperData {
        // immutable data
        uint8 quoteTokenDecimals;
        uint8 baseTokenDecimals;
        uint8 feeTokenDecimals;
        uint8 oracleQuoteTokenPerBaseTokenDecimals;
        uint8 oracleQuoteTokenPerFeeTokenDecimals;
        uint256 extraCoefMultiplier;
        uint256 oracleQuoteTokenPerBaseTokenMultiplier;
        uint256 oracleQuoteTokenPerFeeTokenMultiplier;
        uint256 feeCoefMultiplier;
        uint256 investCoefMultiplier;
        uint256 returnPercentMultiplier;
        /// mutable data
        uint256 initLiquidity;
        uint256 investCoef;
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

    struct TotalProfits {
        uint256 quoteTokenYieldProfit; // [quoteTokenYieldProfit] = quoteToken
        uint256 baseTokenYieldProfit; // [baseTokenYieldProfit] = baseToken
        uint256 quoteTokenTradeProfit; // [quoteTokenTradeProfit] = quoteToken
        uint256 baseTokenTradeProfit; // [baseTokenTradeProfit] = baseToken
    }

    function poolsNFT() external view returns (IPoolsNFT);

    function poolId() external view returns (uint256);

    function deposit(uint256 quoteTokenAmount) external returns (uint256 deposited);

    function withdraw(address to, uint256 quoteTokenAmount) external returns (uint256 withdrawn);

    function exit() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function long_buy() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function long_sell() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function hedge_sell() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function hedge_rebuy() external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    /// @dev calls long_buy, long_sell, hedge_sell, hedge_rebuy
    function iterate() external returns (bool iterated);

    function beforeRebalance() external returns (uint256 baseTokenAmount, uint256 price);

    function afterRebalance(uint256 baseTokenAmount, uint256 newPrice) external;

    function getPriceQuoteTokenPerBaseToken() external view returns (uint256 price);

    function getPriceQuoteTokensPerFeeToken() external view returns (uint256 price);

    function getPriceBaseTokensPerFeeToken(uint256 quoteTokenPerBaseTokenPrice)
        external
        view
        returns (uint256 baseTokensPerFeeTokenPrice);

    function calcQuoteTokenByBaseToken(uint256 baseTokenAmount, uint256 quoteTokenPerBaseTokenPrice)
        external
        view
        returns (uint256 quoteTokenAmount);

    function calcQuoteTokenByFeeToken(uint256 feeTokenAmount, uint256 quoteTokenPerFeeTokenPrice)
        external
        view
        returns (uint256 quoteTokenAmount);

    function calcBaseTokenByFeeToken(uint256 feeTokenAmount, uint256 baseTokenPerFeeTokenPrice)
        external
        view
        returns (uint256 baseTokenAmount);

    function calcFeeTokenByQuoteToken(uint256 quoteTokenAmount) external view returns (uint256 feeTokenAmount);

    function strategyId() external pure returns (uint16);

    function getQuoteToken() external view returns (IToken);

    function getBaseToken() external view returns (IToken);

    function getQuoteTokenAmount() external view returns (uint256 quoteTokenAmount);

    function getBaseTokenAmount() external view returns (uint256 baseTokenAmount);

    function ROI() external view returns (uint256 ROINumerator, uint256 ROIDenominator, uint256 ROIPeriod);

    function APR() external view returns (uint256 APRNumerator, uint256 APRDenominator);

    function getTotalProfits()
        external
        view
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        );

    function getPositions() external view returns (Position memory, Position memory);

    function getTVL() external view returns (uint256);

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

    function getConfig()
        external
        view
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 averagePriceVolatility,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        );
}
