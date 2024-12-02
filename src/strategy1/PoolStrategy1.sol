// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IPoolStrategy, IERC5313} from "src/interfaces/IPoolStrategy.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {UniswapV3AdapterArbitrum} from "src/adapters/UniswapV3AdapterArbitrum.sol";
import {AAVEV3AdapterArbitrum} from "src/adapters/AAVEV3AdapterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PoolStrategy1
/// @author Triple Panic Labs, CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice strategy pool, that put and take baseToken and quouteToken on AAVEV3 and swaps tokens on UniswapV3
/// @dev stores the tokens LP and handles tokens swaps
contract PoolStrategy1 is
    IPoolStrategy,
    AAVEV3AdapterArbitrum,
    UniswapV3AdapterArbitrum
{
    using SafeERC20 for IToken;

    /// @dev address of NFT collection of pools
    /// @dev if address dont implement interface `IPoolsNFT`, that owner is this address
    IPoolsNFT public poolsNFT;

    /// @dev index of position in `poolsNFT`
    uint256 public poolId;

    /// @dev timestamp of deployment
    uint256 public poolDeploymentTimestamp;

    /// @dev price feed of fee token. [oracle] = quoteToken/feeToken
    ///      for Ethereum mainnet = ETH, for BSC = BNB, Optimism = ETH, etc
    AggregatorV3Interface public oracleQuoteTokenPerFeeToken;

    /// @dev price feed of base token. [oracle] = quoteToken/baseToken
    AggregatorV3Interface public oracleQuoteTokenPerBaseToken;

    /// @dev set of helper params
    HelperData public helper;

    /// @dev address of fee token
    IToken public feeToken;

    /// @dev address of base token
    IToken public baseToken;

    /// @dev address of quote token
    IToken public quoteToken;

    /// @dev fee coeficients
    FeeConfig public feeConfig;

    /// @dev config for URUS alg
    Config public config;

    /// @dev set of long position params
    Position public long;

    /// @dev set of hedge position params
    Position public hedge;

    /// @dev total profits of pool
    TotalProfits public totalProfits;

    constructor() {} // only for verification simplification. As constructor call init

    function init(
        address _poolsNFT,
        uint256 _poolId,
        StrategyConstructorArgs memory strategyArgs,
        Config memory conf
    ) public {
        if (address(poolsNFT) != address(0)) {
            revert StrategyInitialized();
        }
        initLending(strategyArgs.lendingArgs);
        initDex(
            strategyArgs.baseToken,
            strategyArgs.quoteToken,
            strategyArgs.dexArgs
        );

        poolsNFT = IPoolsNFT(_poolsNFT);
        poolId = _poolId;
        poolDeploymentTimestamp = block.timestamp;

        oracleQuoteTokenPerFeeToken = AggregatorV3Interface(
            strategyArgs.oracleQuoteTokenPerFeeToken
        );
        oracleQuoteTokenPerBaseToken = AggregatorV3Interface(
            strategyArgs.oracleQuoteTokenPerBaseToken
        );

        feeToken = IToken(strategyArgs.feeToken);
        baseToken = IToken(strategyArgs.baseToken);
        quoteToken = IToken(strategyArgs.quoteToken);

        feeConfig = FeeConfig({
            longSellFeeCoef: 1_00, // x1.00
            hedgeSellFeeCoef: 1_00, // x1.00
            hedgeRebuyFeeCoef: 1_00 // x1.00
        });

        if (
            conf.longNumberMax == 0 ||
            conf.hedgeNumberMax == 0 ||
            conf.averagePriceVolatility == 0 ||
            conf.extraCoef == 0
        ) {
            revert InvalidConfig();
        }
        config = conf;

        _initHelperTokensDecimalsParams();
        _initHelperOracleParams();
        _initHelperCoefParams();
        _setHelperInitLiquidityAndInvestCoef();

        long = Position({
            number: 0,
            numberMax: 0,
            priceMin: type(uint256).max,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
        hedge = Position({
            number: 0,
            numberMax: 0,
            priceMin: 0,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
    }

    function _initHelperTokensDecimalsParams() private {
        helper.baseTokenDecimals = baseToken.decimals();
        helper.quoteTokenDecimals = quoteToken.decimals();
        helper.feeTokenDecimals = feeToken.decimals();
    }

    function _initHelperOracleParams() private {
        helper.oracleQuoteTokenPerFeeTokenDecimals = oracleQuoteTokenPerFeeToken
            .decimals();
        helper
            .oracleQuoteTokenPerBaseTokenDecimals = oracleQuoteTokenPerBaseToken
            .decimals();
        helper.oracleQuoteTokenPerFeeTokenMultiplier =
            10 ** helper.oracleQuoteTokenPerFeeTokenDecimals;
        helper.oracleQuoteTokenPerBaseTokenMultiplier =
            10 ** helper.oracleQuoteTokenPerBaseTokenDecimals;
    }

    function _initHelperCoefParams() private {
        uint8 coefDecimals = 2;
        uint8 percentDecimals = 4;

        helper.extraCoefMultiplier = 10 ** coefDecimals;
        helper.feeCoefMultiplier = 10 ** coefDecimals;
        helper.investCoefMultiplier = 10 ** coefDecimals;
        helper.returnPercentMultiplier = 10 ** percentDecimals;
    }

    function _setHelperInitLiquidityAndInvestCoef() private {
        uint256 maxLiquidity = calcMaxLiquidity();
        helper.investCoef = calcInvestCoef();
        helper.initLiquidity =
            (maxLiquidity * helper.investCoefMultiplier) /
            helper.investCoef;
    }

    /// @dev makes request of ownership to NFT
    function _onlyOwner()
        internal
        view
        override(AAVEV3AdapterArbitrum, UniswapV3AdapterArbitrum)
    {
        address _owner = owner();
        if (msg.sender != _owner) {
            revert NotOwner(msg.sender, _owner);
        }
    }

    /// @dev checks that msg.sender is poolsNFT
    function _onlyPoolsNFT() internal view {
        if (msg.sender != address(poolsNFT)) {
            revert NotPositionsNFT(msg.sender, address(poolsNFT));
        }
    }

    //// ONLY POOL OWNER //////////////////////////////////////////////////////////////////////////

    /// @notice sets config of strategy pool
    function setConfig(Config memory conf) public {
        _onlyOwner();
        if (
            conf.longNumberMax == 0 ||
            conf.hedgeNumberMax == 0 ||
            conf.extraCoef == 0
        ) {
            revert InvalidConfig();
        }
        config = conf;
        _setHelperInitLiquidityAndInvestCoef();
    }

    /// @notice sets long number max
    /// @param longNumberMax new long number max
    function setLongNumberMax(uint8 longNumberMax) public {
        _onlyOwner();
        if (longNumberMax == 0) {
            revert InvalidLongNumberMax();
        }
        config.longNumberMax = longNumberMax;
        _setHelperInitLiquidityAndInvestCoef();
    }

    /// @notice sets hedge number max
    /// @param hedgeNumberMax new hedge number max
    function setHedgeNumberMax(uint8 hedgeNumberMax) public {
        _onlyOwner();
        if (hedgeNumberMax == 0) {
            revert InvalidHedgeNumberMax();
        }
        config.hedgeNumberMax = hedgeNumberMax;
    }

    /// @notice sets extra coef
    /// @param extraCoef new extra coef
    function setExtraCoef(uint256 extraCoef) public {
        _onlyOwner();
        if (extraCoef == 0) {
            revert InvalidExtraCoef();
        }
        config.extraCoef = extraCoef;
        _setHelperInitLiquidityAndInvestCoef();
    }

    /// @notice set fee coeficient for StrategyOp
    /// @dev if realFeeCoef = 1.61, than feeConfig = realFeeCoef * helper.feeCoeficientMultiplier
    /// @param _feeCoef fee coeficient scaled by helper.feeCoeficientMultiplier
    function setOpFeeCoef(StrategyOp op, uint256 _feeCoef) public {
        _onlyOwner();
        if (op == StrategyOp.LONG_SELL) {
            feeConfig.longSellFeeCoef = _feeCoef;
        } else if (op == StrategyOp.HEDGE_SELL) {
            feeConfig.hedgeSellFeeCoef = _feeCoef;
        } else if (op == StrategyOp.HEDGE_REBUY) {
            feeConfig.hedgeRebuyFeeCoef = _feeCoef;
        } else {
            revert InvalidStrategyOpForFeeCoef();
        }
    }

    /// @notice set retunr for StrategyOp
    /// @dev if realRoi == 100.5%=1.005, than returnPercent == realRoi * helper.returnPercentMultiplier
    /// @param op operation to apply return
    /// @param returnPercent return scaled by helper.returnPercentMultiplier
    function setOpReturnPercent(StrategyOp op, uint256 returnPercent) public {
        _onlyOwner();
        if (returnPercent < 100 * helper.returnPercentMultiplier)
            revert InvalidReturnOfInvestment();
        if (op == StrategyOp.LONG_SELL) {
            config.returnPercentLongSell = returnPercent;
        } else if (op == StrategyOp.HEDGE_SELL) {
            config.returnPercentHedgeSell = returnPercent;
        } else if (op == StrategyOp.HEDGE_REBUY) {
            config.returnPercentHedgeRebuy = returnPercent;
        } else {
            revert InvalidStrategyOpForReturn();
        }
    }

    //// ONLY POOLS NFT //////////////////////////////////////////////////////////////////////////

    /// @notice deposit the quote token to strategy
    /// @dev callable only by pools NFT
    /// @param quoteTokenAmount raw amount of `quoteToken`
    /// @return deposited quoteToken amount
    function deposit(
        uint256 quoteTokenAmount
    ) public returns (uint256 deposited) {
        _onlyPoolsNFT();
        quoteToken.safeTransferFrom(
            msg.sender,
            address(this),
            quoteTokenAmount
        );
        _invest(quoteTokenAmount);
        uint256 putAmount = put(quoteToken, quoteTokenAmount);
        deposited = putAmount;
    }

    /// @notice take `quoteTokenAmount` from lending, deinvest `quoteTokenAmount` and transfer it to `to`
    /// @dev callable only by pools NFT
    /// @param to address that receive the `quoteTokenAmount`
    /// @param quoteTokenAmount amount of quoteToken
    /// @return withdrawn quoteToken amount
    function withdraw(
        address to,
        uint256 quoteTokenAmount
    ) public returns (uint256 withdrawn) {
        _onlyPoolsNFT();
        uint256 maxLiqudity = calcMaxLiquidity();
        if (quoteTokenAmount > maxLiqudity) {
            revert QuoteTokenAmountExceededMaxLiquidity();
        }
        if (long.number == 0) {
            uint256 takeAmount = take(quoteToken, quoteTokenAmount);
            _divest(takeAmount);
            quoteToken.safeTransfer(to, takeAmount);
            withdrawn = takeAmount;
        } else {
            revert QuoteTokenInvested();
        }
    }

    /// @notice invest amount of `quoteToken`
    /// @dev recalculates the initLiquidity
    /// @param investAmount amount of `quoteToken` to invest. Accumulates from fee
    function _invest(
        uint256 investAmount
    ) internal returns (uint256 newMaxLiquidity) {
        if (investAmount == 0) {
            return 0;
        }
        /**
         * Example: longNumberMax == 4
         *         1) no liquidity deposited: invest:=50
         *         newMaxLiquidity = 0 * 27_00 / 1_00 + 50 = 0 + 50 = 50
         *         newInitLiqudity = 50 * 1_00 / 27_00 = 1.185185
         *
         *         2) liquidity deposited and fees is reinvested:
         *         initLiquidity:=10
         *         reinvest:=5
         *         newMaxLiquidity = 10 * 27_00 / 1_00  + 5 = 270 + 5 = 275
         *         newInitLiqudity = 275 * 1_00 / 27_00 = 10.185185
         */
        newMaxLiquidity = calcMaxLiquidity() + investAmount;
        helper.initLiquidity =
            (newMaxLiquidity * helper.investCoefMultiplier) /
            helper.investCoef;
    }

    /// @notice divest amount of quoteToken
    /// @dev recalculate the initLiquidity
    /// @param divestAmount amount of `quoteToken` to divest
    function _divest(
        uint256 divestAmount
    ) internal returns (uint256 newMaxLiquidity) {
        uint256 maxLiqudity = calcMaxLiquidity();
        if (maxLiqudity < divestAmount) {
            revert DivestExceedsMaxLiquidity();
        }
        newMaxLiquidity = maxLiqudity - divestAmount;
        helper.initLiquidity =
            (newMaxLiquidity * helper.investCoefMultiplier) /
            helper.investCoef;
    }

    /// @notice calculate max liquidity that can be used for buying
    function calcMaxLiquidity() public view returns (uint256) {
        return
            (helper.initLiquidity * helper.investCoef) /
            helper.investCoefMultiplier;
    }

    /// @notice calculates invest coeficient
    /// @dev q_n = (e+1) ^ (n-1) * q_1 => investCoef = (e+1)^(n-1)
    function calcInvestCoef() public view returns (uint256 investCoef) {
        uint8 exponent = config.longNumberMax - 1;
        uint256 multiplier = helper.extraCoefMultiplier;
        if (exponent >= 2) {
            investCoef =
                (config.extraCoef + multiplier) ** exponent /
                (multiplier ** (exponent - 1));
        } else if (exponent == 1) {
            investCoef = config.extraCoef + multiplier;
        } else {
            // exponent == 0
            investCoef = multiplier;
        }
    }

    /// @notice grab all assets from strategy and send it to owner
    /// @return quoteTokenAmount amount of quoteToken in exit
    /// @return baseTokenAmount amount of baseToken in exit
    function exit()
        public
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        _onlyPoolsNFT();
        (quoteTokenAmount) = take(quoteToken, type(uint256).max);
        (baseTokenAmount) = take(baseToken, type(uint256).max);
        uint256 quoteTokenBalance = quoteToken.balanceOf(address(this));
        uint256 baseTokenBalance = baseToken.balanceOf(address(this));
        address _owner = owner();
        if (quoteTokenBalance > 0) {
            quoteToken.safeTransfer(_owner, quoteTokenBalance);
        }
        if (baseTokenBalance > 0) {
            baseToken.safeTransfer(_owner, baseTokenBalance);
        }

        long = Position({
            number: 0,
            numberMax: 0,
            priceMin: type(uint256).max,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
        hedge = Position({
            number: 0,
            numberMax: 0,
            priceMin: 0,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
    }

    /// @notice distribute yield profit
    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal override {
        if (token == baseToken) {
            totalProfits.baseTokenYieldProfit += profit;
        } else if (token == quoteToken) {
            totalProfits.quoteTokenYieldProfit += profit;
        }
        _distributeProfit(token, profit);
    }

    /// @notice distribute trade profit
    function _distributeTradeProfit(
        IToken token,
        uint256 profit
    ) internal override {
        if (token == baseToken) {
            totalProfits.baseTokenTradeProfit += profit;
        } else if (token == quoteToken) {
            totalProfits.quoteTokenTradeProfit += profit;
        }
        _distributeProfit(token, profit);
    }

    /// @notice distribute profit
    function _distributeProfit(IToken token, uint256 profit) internal {
        (
            address[] memory receivers,
            uint256[] memory amounts
        ) = poolsNFT.calcRoyaltyShares(poolId, profit);
        uint256 len = receivers.length;
        if (len != amounts.length) {
            revert InvalidLength();
        }
        uint256 i;
        for (;i < len;) {
            if (amounts[i] > 0) {
                token.safeTransfer(receivers[i], amounts[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    //// GRIND FUNCTIONS ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPoolStrategy
    function long_buy()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();
        // 0. verify that liquidity limit not exceeded
        uint8 longNumber = long.number;
        if (longNumber != 0 && longNumber >= long.numberMax) {
            revert LongNumberMax();
        }
        // 1.1. calculate the quote token amount
        if (longNumber == 0) {
            quoteTokenAmount = helper.initLiquidity;
        } else {
            quoteTokenAmount =
                (long.liquidity * config.extraCoef) /
                helper.extraCoefMultiplier;
        }
        // 1.2. Take the quoteToken from lending protocol
        (quoteTokenAmount) = take(quoteToken, quoteTokenAmount);

        // 2.0 Swap quoteTokenAmount to baseTokenAmount on DEX
        baseTokenAmount = swap(quoteToken, baseToken, quoteTokenAmount);
        uint256 baseTokenPrice = calcSwapPrice(
            quoteTokenAmount,
            baseTokenAmount
        ); // [baseTokenPrice] = quoteToken/baseToken
        if (baseTokenPrice > long.priceMin) {
            revert BuyUpperPriceMin(baseTokenPrice, long.priceMin);
        }

        // 3.1. Update position
        if (longNumber == 0) {
            long.numberMax = config.longNumberMax;
        }
        long.number += 1;
        long.price =
            (long.qty * long.price + baseTokenAmount * baseTokenPrice) /
            (long.qty + baseTokenAmount);
        long.qty += baseTokenAmount;
        long.liquidity += quoteTokenAmount;
        long.priceMin = long.price - config.averagePriceVolatility;

        // 4.1. Put baseToken to lending protocol
        (baseTokenAmount) = put(baseToken, baseTokenAmount);

        // 5.1. Accumulate fees
        uint256 feePrice = getPriceQuoteTokensPerFeeToken(); // [long.feePrice] = quoteToken/feeToken
        uint256 txGasPrice = tx.gasprice;
        if (txGasPrice > 0) {
            uint256 feeQty = (gasStart - gasleft() + 50) * txGasPrice; // gas * feeToken / gas = feeToken
            long.feePrice =
                (long.feeQty * long.feePrice + feeQty * feePrice) /
                (long.feeQty + feeQty);
            long.feeQty += feeQty;
        }
    }

    /// @inheritdoc IPoolStrategy
    function long_sell()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        // 0. Verify that number != 0
        if (long.number == 0) {
            revert NoBuy();
        }
        if (hedge.number > 0) {
            revert Hedged();
        }

        // 1. Take all qty from lending protocol
        baseTokenAmount = long.qty;
        (baseTokenAmount) = take(baseToken, baseTokenAmount);

        // 2.1. Swap baseTokenAmount to quoteTokenAmount
        quoteTokenAmount = swap(baseToken, quoteToken, baseTokenAmount);
        // 2.2. Calculate threshold and swapPriceThreshold
        (uint256 quoteTokenAmountThreshold, ) = calcLongSellThreshold();
        if (quoteTokenAmount <= quoteTokenAmountThreshold) {
            revert NotProfitableLongSell();
        }

        // 3.0. Calculate and distribute profit
        uint256 profitPlusFees = quoteTokenAmount - long.liquidity;
        quoteTokenAmount -= profitPlusFees;
        _distributeTradeProfit(quoteToken, profitPlusFees);

        // 4.0 Put the rest of `quouteToken` to lending protocol
        (quoteTokenAmount) = put(quoteToken, quoteTokenAmount);

        long = Position({
            number: 0,
            numberMax: 0,
            priceMin: type(uint256).max,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
    }

    /// @inheritdoc IPoolStrategy
    function hedge_sell()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();

        // 0. Verify that under_sell can be executed
        if (long.number < long.numberMax) {
            revert NotLongNumberMax();
        }
        uint8 hedgeNumber = hedge.number;
        uint8 hedgeNumberMaxMinusOne = hedge.numberMax - 1;

        // 1.1. Define the base token amount to hedge sell
        if (hedgeNumber == 0) {
            baseTokenAmount = long.qty / (2 ** hedgeNumberMaxMinusOne);
        } else if (hedgeNumber < hedgeNumberMaxMinusOne) {
            baseTokenAmount = hedge.qty;
        } else if (hedgeNumber == hedgeNumberMaxMinusOne) {
            baseTokenAmount = long.qty;
        }
        // 1.2. Take the baseToken from lending protocol
        (baseTokenAmount) = take(baseToken, baseTokenAmount);

        // 2.1 Swap the base token amount to quote token
        quoteTokenAmount = swap(baseToken, quoteToken, baseTokenAmount);
        uint256 swapPrice = calcSwapPrice(quoteTokenAmount, baseTokenAmount); // [swapPrice] = quoteToken/baseToken

        if (hedgeNumber == 0) {
            // INITIALIZE HEDGE SELL
            uint256 thresholdHigh = long.priceMin;
            uint256 thresholdLow = long.priceMin -
                2 *
                config.averagePriceVolatility;
            if (swapPrice > thresholdHigh || thresholdLow < swapPrice) {
                revert HedgeSellOutOfBound(
                    swapPrice,
                    thresholdHigh,
                    thresholdLow
                );
            }
            hedge.priceMin = swapPrice;
            hedge.price = swapPrice;
        } else {
            // HEDGE SELL
            (
                uint256 liquidity,
                uint256 quoteTokenAmountThreshold,
                uint256 targetPrice,

            ) = calcHedgeSellThreshold(baseTokenAmount);
            if (quoteTokenAmount <= quoteTokenAmountThreshold) {
                revert NotProfitableHedgeSell();
            }

            uint256 profitPlusFees = quoteTokenAmount - liquidity; // profit with fees
            quoteTokenAmount -= profitPlusFees;
            _distributeTradeProfit(quoteToken, profitPlusFees);

            hedge.price = targetPrice;
        }

        // 3.1. Put the quote token to lending protocol
        (quoteTokenAmount) = put(quoteToken, quoteTokenAmount);

        if (hedgeNumber < hedgeNumberMaxMinusOne) {
            long.qty -= baseTokenAmount;
            hedge.qty += baseTokenAmount;
            hedge.liquidity += quoteTokenAmount;
            hedge.number += 1;

            uint256 feePrice = getPriceBaseTokensPerFeeToken(swapPrice); // [feePrice] = baseToken/feeToken
            uint256 txGasPrice = tx.gasprice;
            if (txGasPrice > 0) {
                // gasStart always bigger than gasleft()
                uint256 feeQty = (gasStart - gasleft() + 50) * txGasPrice; // [feeQty] = gas * feeToken / gas = feeToken
                // [hedge.feePrice] = (feeToken * (baseToken/feeToken) + feeToken * (baseToken/feeToken)) / (feeToken + feeToken) =
                //                  = (baseToken + baseToken) / feeToken = baseToken / feeToken
                hedge.feePrice =
                    (hedge.feeQty * hedge.feePrice + feeQty * feePrice) /
                    (hedge.feeQty + feeQty);
                hedge.feeQty += feeQty;
            }
        } else if (hedgeNumber == hedgeNumberMaxMinusOne) {
            long = Position({
                number: 0,
                numberMax: 0,
                priceMin: type(uint256).max,
                liquidity: 0,
                qty: 0,
                price: 0,
                feeQty: 0,
                feePrice: 0
            });
            hedge = Position({
                number: 0,
                numberMax: 0,
                priceMin: 0,
                liquidity: 0,
                qty: 0,
                price: 0,
                feeQty: 0,
                feePrice: 0
            });
        }
    }

    /// @inheritdoc IPoolStrategy
    function hedge_rebuy()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        // 0. Verify that hedge is activated
        uint8 hedgeNumber = hedge.number;
        if (hedgeNumber > 0) {
            revert NoHedge(); // require(hedgeNumber == 0, "Hedged!")
        }

        // 1.1. Define how much to rebuy
        quoteTokenAmount = hedge.liquidity;
        // 1.2. Take base token amount
        (quoteTokenAmount) = take(quoteToken, quoteTokenAmount);

        // 2.1 Swap quoteToken to baseToken
        baseTokenAmount = swap(quoteToken, baseToken, quoteTokenAmount);
        uint256 swapPrice = calcSwapPrice(quoteTokenAmount, baseTokenAmount);

        (uint256 baseTokenAmountThreshold, ) = calcHedgeRebuyThreshold(
            quoteTokenAmount
        );
        if (baseTokenAmount <= baseTokenAmountThreshold) {
            revert NotProfitableRebuy();
        }

        uint256 profitPlusFees = baseTokenAmount - hedge.qty;
        _distributeTradeProfit(baseToken, profitPlusFees);
        baseTokenAmount -= profitPlusFees;

        // 3.1. Put the baseToken to lending protocol
        (baseTokenAmount) = put(baseToken, baseTokenAmount);

        long.price =
            (long.qty *
                long.price +
                hedge.qty *
                (swapPrice + long.price - hedge.price)) /
            (long.qty + hedge.qty);
        long.qty += baseTokenAmount;

        hedge = Position({
            number: 0,
            numberMax: 0,
            priceMin: 0,
            liquidity: 0,
            qty: 0,
            price: 0,
            feeQty: 0,
            feePrice: 0
        });
    }

    /// @notice iteration of URUS algorithm
    /// @dev calls long_buy, long_sell, hedge_sell, hedge_rebuy
    /// @return iterated true if successfully operation made, false otherwise
    function iterate() public returns (bool iterated) {
        IPoolStrategy strategy = IPoolStrategy(address(this));
        if (long.number == 0) {
            // BUY
            try strategy.long_buy() returns (
                uint256 quoteTokenAmount,
                uint256 baseTokenAmount
            ) {
                iterated = true;
                emit LongBuy(poolId, quoteTokenAmount, baseTokenAmount);
            } catch {}
        } else if (long.number < long.numberMax) {
            // SELL
            try strategy.long_sell() returns (
                uint256 quoteTokenAmount,
                uint256 baseTokenAmount
            ) {
                iterated = true;
                emit LongSell(poolId, quoteTokenAmount, baseTokenAmount);
            } catch {
                // EXTRA BUY
                try strategy.long_buy() returns (
                    uint256 quoteTokenAmount,
                    uint256 baseTokenAmount
                ) {
                    iterated = true;
                    emit LongBuy(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
            }
        } else {
            // long.number == long.numberMax
            if (hedge.number == 0) {
                // TRY SELL
                try strategy.long_sell() returns (
                    uint256 quoteTokenAmount,
                    uint256 baseTokenAmount
                ) {
                    iterated = true;
                    emit LongSell(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {
                    // INIT HEDGE SELL
                    try strategy.hedge_sell() returns (
                        uint256 quoteTokenAmount,
                        uint256 baseTokenAmount
                    ) {
                        iterated = true;
                        emit HedgeSell(
                            poolId,
                            quoteTokenAmount,
                            baseTokenAmount
                        );
                    } catch {}
                }
            } else {
                // hedge.number > 0
                // REBUY
                try strategy.hedge_rebuy() returns (
                    uint256 quoteTokenAmount,
                    uint256 baseTokenAmount
                ) {
                    iterated = true;
                    emit HedgeRebuy(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {
                    // TRY HEDGE SELL
                    try strategy.hedge_sell() returns (
                        uint256 quoteTokenAmount,
                        uint256 baseTokenAmount
                    ) {
                        iterated = true;
                        emit HedgeSell(
                            poolId,
                            quoteTokenAmount,
                            baseTokenAmount
                        );
                    } catch {}
                }
            }
        }
    }

    //// REBALANCE FUNCTIONS ////////////////////////////////////////////////////////////////////////

    /// @notice first step for rebalance the positions via poolsNFT
    /// @dev called before rebalance by poolsNFT
    /// @return baseTokenAmount base token amount that take part in rebalance
    /// @return price base token price scaled by price multuplier
    function beforeRebalance()
        public
        returns (uint256 baseTokenAmount, uint256 price)
    {
        _onlyPoolsNFT();
        if (hedge.number > 0) {
            revert Hedged();
        }
        if (long.number < config.longNumberMax) {
            revert NotLongNumberMax();
        }

        (baseTokenAmount) = take(baseToken, long.qty);
        baseToken.approve(address(poolsNFT), baseTokenAmount);
        long.qty -= baseTokenAmount;
        price = long.price;
    }

    /// @notice third step for rebalance the positions via poolsNFT
    /// @dev called after rebalance by poolsNFT
    function afterRebalance(uint256 baseTokenAmount, uint256 newPrice) public {
        _onlyPoolsNFT();
        baseToken.safeTransferFrom(msg.sender, address(this), baseTokenAmount);
        (baseTokenAmount) = put(baseToken, baseTokenAmount);
        long.liquidity =
            (baseTokenAmount * newPrice) /
            helper.oracleQuoteTokenPerBaseTokenMultiplier;
        long.qty = baseTokenAmount;
        long.price = newPrice;
    }

    //// PRICES /////////////////////////////////////////////////////////////////////////////////////////

    /// @notice returns `baseToken` price in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/baseToken
    function getPriceQuoteTokenPerBaseToken()
        public
        view
        returns (uint256 price)
    {
        (, int256 answer, , , ) = oracleQuoteTokenPerBaseToken
            .latestRoundData();
        price = uint256(answer);
    }

    /// @notice returns price of `feeToken` in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/feeToken
    function getPriceQuoteTokensPerFeeToken()
        public
        view
        returns (uint256 price)
    {
        (, int256 answer, , , ) = oracleQuoteTokenPerFeeToken.latestRoundData();
        price = uint256(answer);
    }

    /// @notice returns price of `feeToken` in terms of `baseToken`
    /// @dev dimention [price]= baseToken/feeToken
    function getPriceBaseTokensPerFeeToken(
        uint256 quoteTokenPerBaseTokenPrice
    ) public view returns (uint256 price) {
        (, int256 answer, , , ) = oracleQuoteTokenPerFeeToken.latestRoundData();
        // [price] = quoteToken / feeToken * (1 / (quoteToken / baseToken)) = baseToken / feeToken
        price =
            (uint256(answer) * helper.oracleQuoteTokenPerBaseTokenMultiplier) /
            quoteTokenPerBaseTokenPrice;
    }

    //// CALCULATE FUNCTIONS ////////////////////////////////////////////////////////////////////////////////

    /// @notice calculates the price of `baseToken` in terms of `quoteToken` based on `quoteTokenAmount` and `baseTokenAmount`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @param baseTokenAmount amoint of `baseToken`
    /// @return price the price of 1 `baseToken`. Dimension: [price] = quoteToken/baseToken
    function calcSwapPrice(
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    ) public view returns (uint256 price) {
        uint8 bd = helper.baseTokenDecimals;
        uint8 qd = helper.quoteTokenDecimals;
        uint8 pd = helper.oracleQuoteTokenPerBaseTokenDecimals;
        if (pd >= qd) {
            price =
                (quoteTokenAmount * (10 ** (bd + pd - qd))) /
                baseTokenAmount;
        } else {
            price =
                (quoteTokenAmount * (10 ** bd)) /
                (baseTokenAmount * (10 ** (qd - pd)));
        }
    }

    /// @notice calculates long sell thresholds
    /// @return quoteTokenAmountThreshold threshold amount of `quoteToken`
    /// @return swapPriceThreshold threshold price to execute swap
    function calcLongSellThreshold()
        public
        view
        returns (uint256 quoteTokenAmountThreshold, uint256 swapPriceThreshold)
    {
        uint256 feeQty = (long.feeQty * feeConfig.longSellFeeCoef) /
            helper.feeCoefMultiplier;
        uint256 buyFee;
        if (feeToken == quoteToken) {
            buyFee = feeQty; // [buyFee] = quoteToken
        } else {
            buyFee = calcQuoteTokenByFeeToken(feeQty, long.feePrice); // [buyFee] = feeToken *  quoteToken / feeToken = quoteToken
        }
        uint256 sellFee = buyFee / long.number; // estimated sell fee. [sellFee] = quoteToken
        uint256 fees = buyFee + sellFee;
        /**
         * PROOF of liquidity threshold:
         *         returnPercent = (qty * price + buyFee + sellFee + profit) / qty * price + buyFee + sellFee
         *         profit = returnPercent * (qty * price + buyFee + sellFee) - (qty * price + buyFee + sellFee) = (returnPercent - 1) * (qty * price + buyFee + sellFee)
         *         profit = (returnPercent - 1) * (qty * price + buyFee + sellFee)
         *         qty * swapPrice >= qty * price + buyFee + sellFee + profit = qty * price + buyFee + sellFee + (returnPercent - 1) * (qty * price + buyFee + sellFee)
         *         qty * swapPrice >= (qty * price + buyFee + sellFee) * (1 + returnPercent - 1) = (qty * price + buyFee + sellFee) * returnPercent
         *         So,
         *         1) liquidity = qty * swapPrice >= (qty * price + buyFee + sellFee) * returnPercent == qty * price + buyFee + sellFee + profit
         *         2) profit = liquidity - (qty * price + buyFee + sellFee)
         */
        /**
         * Visual of quoteTokenAmount
         *     |-------|-----------------|-----------------------|---------------------|-------------> quoteToken
         *             ^                 ^                       ^                     ^
         *         liquidity       liquidity+fees      liquidity+fees+profit    quouteTokenAmount
         *                               ||                     ||
         *                        liquidityPlusFee   quoteTokenAmountThreshold
         *
         *         liqudity < liquidity+fees < liquidity+fees+profit <= quouteTokenAmount
         *                                              ||
         *                                   quoteTokenAmountThreshold
         */
        quoteTokenAmountThreshold =
            ((long.liquidity + fees) * config.returnPercentLongSell) /
            helper.returnPercentMultiplier;
        swapPriceThreshold = calcSwapPrice(quoteTokenAmountThreshold, long.qty);
    }

    /// @notice calculates target hedge price for undersell
    /// @param hedgeNumber the number of hedge
    /// @param priceMin minimum price, when undersell happened on hedgeNumber==0
    /// @param priceMax maximum price, where are targeting to
    function calcTargetHedgePrice(
        uint8 hedgeNumber,
        uint256 priceMin,
        uint256 priceMax
    ) public view returns (uint256 targetPrice) {
        uint8 hedgeNumberMax = hedge.numberMax;
        if (hedgeNumberMax == 1) {
            targetPrice = priceMax;
        } else {
            targetPrice =
                priceMin +
                ((priceMax - priceMin) * hedgeNumber) /
                (hedgeNumberMax - 1);
        }
    }

    /// @notice calculates hedge sell threshold
    /// @param baseTokenAmount base token amount
    function calcHedgeSellThreshold(
        uint256 baseTokenAmount
    )
        public
        view
        returns (
            uint256 liquidity,
            uint256 quoteTokenAmountThreshold,
            uint256 targetPrice,
            uint256 swapPriceThreshold
        )
    {
        /**
         * Proof of criteria formula
         *      tp = targetPrice, sp = swapPrice, h.q = hedgeQty, h.p = hedgePrice
         *      (h.q + q) * tp <= h.q * h.p + q * sp =  h.q * h.p + q * sp + fee - fee + profit - profit
         *      Lets do this math magic:
         *      L = q * sp + fee + profit = q * sp + q * fee / q + q * profit / q = q * sp + q * sp1 + q * sp2 = q * (sp + sp1 + sp2)
         *      L - this is quote token amount after swap
         *      So, we get:
         *      (h.q + q) * tp <= h.q * h.p + L - fee - profit
         *      (h.q + q) * tp - h.q * h.p + fee + profit <= L
         *      So, criteria: (h.q + q) * tp - h.q * h.p + fee + profit <= L
         *      Rewrite profit for more convinient form in ReturnPercent as we did in long sell:
         *      ((h.q + q) * tp - h.q * h.p + fee) * ReturnPercent <= L
         *      So, profit:
         *      profit = L - ((h.q + q) * tp - h.q * h.p + fee)
         */
        /**
         * Visual of hedge prices. Lets have hedgeNumberMax==3, then:
         *  |-------|-----------------|-------------|------------|-------------|------------|-------------|------------> price
         *       priceMin        targetPrice1   swapPrice1   targetPrice2  swapPrice2    priceMax     swapPrice3
         *          ||                                                                      ||
         *    hedge.priceMin                                                            long.price
         */
        /**
         * Explanation of hedge sell fees:
         *       Imagine that hedge.number iterated to hedgeNumberMax. That means that there are need for compensate the long.feeQty.
         *       This requiments meets in formula for hedge sell fee:
         *       hedgeSellFee = estimated hedge sell fee for 1 execution of hedge sell + partial refund of long.feeQty =
         *                   = long.feeQty / (hedgeNumberMax - 1) + long.feeQty / (hedgeNumberMax - 1)
         *       Total hedgeSellFee is executed (hedgeNumberMax - 1) times.
         *       Then, total hedge sell fees = (hedgeNumberMax - 1) * (long.feeQty / (hedgeNumberMax - 1) + long.feeQty / (hedgeNumberMax - 1)) =
         *                               = long.feeQty + long.feeQty = 2 * long.feeQty
         *       So, hedgeSellFee for 1 execution = 2 * long.feeQty / (hedgeNumberMax - 1)
         */
        uint256 feeQty = (long.feeQty * feeConfig.hedgeSellFeeCoef) /
            helper.feeCoefMultiplier;
        uint256 fees = (2 * calcQuoteTokenByFeeToken(feeQty, long.feePrice)) /
            (hedge.numberMax - 1); // [fees] = quoteToken
        uint256 hedgeQty = hedge.qty;

        // liquidity = (hedge.qty + baseTokenAmount) * targetPrice - hedge.qty * hedge.price;
        targetPrice = calcTargetHedgePrice(
            hedge.number,
            hedge.priceMin,
            long.price
        ); // [targetPrice] = quoteToken/baseToken
        liquidity =
            calcQuoteTokenByBaseToken(hedgeQty + baseTokenAmount, targetPrice) -
            calcQuoteTokenByBaseToken(hedgeQty, hedge.price);
        quoteTokenAmountThreshold =
            ((liquidity + fees) * config.returnPercentHedgeSell) /
            helper.returnPercentMultiplier;
        swapPriceThreshold = calcSwapPrice(
            quoteTokenAmountThreshold,
            baseTokenAmount
        );
    }

    /// @notice calculates hedge rebuy threshold
    /// @param quoteTokenAmount quote token amount
    function calcHedgeRebuyThreshold(
        uint256 quoteTokenAmount
    )
        public
        view
        returns (uint256 baseTokenAmountThreshold, uint256 swapPriceThreshold)
    {
        /**
         * FORMULA for rebuy (Without proof, because it is simple)
         *      h.q + fee + profit <= baseTokenAmount
         */
        /**
         * Rebuy fee:
         *      hedgeRebuyFee = estimation for 1 execution of rebuy as sum of all hedge sell fees divided to hedge.number + sum of all hedge sell fees =
         *                    = hedgeSellFees / hedge.number + hedgeSellFees
         */
        uint256 feeQty = (hedge.feeQty * feeConfig.hedgeRebuyFeeCoef) /
            helper.feeCoefMultiplier;
        uint256 hedgeSellFees; // [hedgeSellFees] = baseToken
        if (feeToken == baseToken) {
            hedgeSellFees = feeQty;
        } else {
            hedgeSellFees = calcBaseTokenByFeeToken(feeQty, hedge.feePrice);
        }
        uint256 hedgeRebuyFee = hedgeSellFees / hedge.number;

        baseTokenAmountThreshold =
            ((hedge.qty + hedgeSellFees + hedgeRebuyFee) *
                config.returnPercentHedgeRebuy) /
            helper.returnPercentMultiplier;
        swapPriceThreshold = calcSwapPrice(
            quoteTokenAmount,
            baseTokenAmountThreshold
        );
    }

    /// @notice calculates baseTokenAmount in terms of `quoteToken` with `baseTokenPrice`
    /// @param baseTokenAmount amount of `baseToken`
    /// @param quoteTokenPerBaseTokenPrice price of `baseToken`
    /// @return quoteTokenAmount amount of `quoteToken`
    function calcQuoteTokenByBaseToken(
        uint256 baseTokenAmount,
        uint256 quoteTokenPerBaseTokenPrice
    ) public view returns (uint256 quoteTokenAmount) {
        uint8 bd = helper.baseTokenDecimals;
        uint8 qd = helper.quoteTokenDecimals;
        if (qd >= bd) {
            quoteTokenAmount =
                (baseTokenAmount *
                    quoteTokenPerBaseTokenPrice *
                    (10 ** (qd - bd))) /
                helper.oracleQuoteTokenPerBaseTokenMultiplier;
        } else {
            quoteTokenAmount =
                (baseTokenAmount * quoteTokenPerBaseTokenPrice) /
                (helper.oracleQuoteTokenPerBaseTokenMultiplier *
                    (10 ** (bd - qd)));
        }
    }

    /// @notice calculate the feeTokenAmount in terms of `quoteToken`
    /// @param feeTokenAmount amount of `feeToken`. [feeTokenAmount]=feeToken
    /// @param quoteTokenPerFeeTokenPrice price of quoteToken per feeToken. [priceQuoteTokenPerFeeToken] = quoteToken/feeToken
    function calcQuoteTokenByFeeToken(
        uint256 feeTokenAmount,
        uint256 quoteTokenPerFeeTokenPrice
    ) public view returns (uint256 quoteTokenAmount) {
        uint8 qd = helper.quoteTokenDecimals;
        uint8 fd = helper.feeTokenDecimals;
        if (qd >= fd) {
            quoteTokenAmount =
                (feeTokenAmount *
                    quoteTokenPerFeeTokenPrice *
                    (10 ** (qd - fd))) /
                helper.oracleQuoteTokenPerFeeTokenMultiplier;
        } else {
            quoteTokenAmount =
                (feeTokenAmount * quoteTokenPerFeeTokenPrice) /
                (helper.oracleQuoteTokenPerFeeTokenMultiplier *
                    (10 ** (fd - qd)));
        }
    }

    /// @notice calculate feeTokenAmount in terms of `baseToken`
    /// @param feeTokenAmount amount of `feeToken`. [feeTokenAmount]=feeToken
    /// @param baseTokenPerFeeTokenPrice price of baseToken per feeToken. [baseTokenPerFeeTokenPrice]=baseToken/feeToken
    /// @return baseTokenAmount amount of `baseToken`
    function calcBaseTokenByFeeToken(
        uint256 feeTokenAmount,
        uint256 baseTokenPerFeeTokenPrice
    ) public view returns (uint256 baseTokenAmount) {
        uint8 bd = helper.baseTokenDecimals;
        uint8 fd = helper.feeTokenDecimals;
        if (bd >= fd) {
            baseTokenAmount =
                (feeTokenAmount *
                    baseTokenPerFeeTokenPrice *
                    (10 ** (bd - fd))) /
                helper.oracleQuoteTokenPerFeeTokenMultiplier;
        } else {
            baseTokenAmount =
                (feeTokenAmount * baseTokenPerFeeTokenPrice) /
                (helper.oracleQuoteTokenPerFeeTokenMultiplier *
                    (10 ** (fd - bd)));
        }
    }

    /// @notice calcultes quoteTokenAmount in terms of `feeToken`
    /// @param quoteTokenAmount amount of `quoteToken`. [quoteTokenAmount] = quoteToken
    /// @return feeTokenAmount amount of `feeToken`
    function calcFeeTokenByQuoteToken(
        uint256 quoteTokenAmount
    ) public view returns (uint256 feeTokenAmount) {
        uint8 qd = helper.quoteTokenDecimals;
        uint8 fd = helper.feeTokenDecimals;
        uint256 quoteTokenPerFeeTokenPrice = getPriceQuoteTokensPerFeeToken(); // [feeTokenPrice] = quoteToken / feeToken
        if (fd >= qd) {
            feeTokenAmount =
                (quoteTokenAmount *
                    helper.oracleQuoteTokenPerFeeTokenMultiplier *
                    (10 ** (fd - qd))) /
                quoteTokenPerFeeTokenPrice;
        } else {
            feeTokenAmount =
                (quoteTokenAmount *
                    helper.oracleQuoteTokenPerFeeTokenMultiplier) /
                (quoteTokenPerFeeTokenPrice * (10 ** (qd - fd)));
        }
    }

    /// @notice calculates return of investment of strategy pool.
    /// @dev returns the numerator and denominator of ROI. ROI = ROINumerator / ROIDenominator
    function ROI()
        public
        view
        returns (
            uint256 ROINumerator,
            uint256 ROIDenominator,
            uint256 ROIPeriod
        )
    {
        uint256 baseTokenPrice = getPriceQuoteTokenPerBaseToken();
        uint256 investment = investedAmount[quoteToken] +
            calcQuoteTokenByBaseToken(
                investedAmount[baseToken],
                baseTokenPrice
            );
        uint256 profits = 0 + // trade profits + yield profits + pending yield profits
            totalProfits.quoteTokenTradeProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenTradeProfit,
                baseTokenPrice
            ) +
            totalProfits.quoteTokenYieldProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenYieldProfit,
                baseTokenPrice
            ) +
            getPendingYield(quoteToken) +
            getPendingYield(baseToken);
        ROINumerator = profits;
        ROIDenominator = investment;
        ROIPeriod = block.timestamp - poolDeploymentTimestamp;
    }

    /// @notice calculates annual percentage rate (APR) of strategy pool
    /// @dev returns the numerator and denominator of APR. APR = APRNumerator / APRDenominator
    function APR()
        public
        view
        returns (uint256 APRNumerator, uint256 APRDenominator)
    {
        (
            uint256 ROINumerator,
            uint256 ROIDenominator,
            uint256 ROIPeriod
        ) = ROI();
        // convert ROI per 1 day
        uint256 oneDayInSeconds = 86400;
        APRNumerator = ROINumerator * ROIPeriod * 365;
        APRDenominator = ROIDenominator * oneDayInSeconds;
    }

    /// @notice returns quote token of strategy
    function getQuoteToken()
        public
        view
        override(
            AAVEV3AdapterArbitrum,
            UniswapV3AdapterArbitrum,
            IPoolStrategy
        )
        returns (IToken)
    {
        return quoteToken;
    }

    /// @notice returns the base token of strategy
    function getBaseToken()
        public
        view
        override(
            AAVEV3AdapterArbitrum,
            UniswapV3AdapterArbitrum,
            IPoolStrategy
        )
        returns (IToken)
    {
        return baseToken;
    }

    /// @notice returns quoteToken amount
    function getQuoteTokenAmount() public view returns (uint256) {
        return investedAmount[quoteToken];
    }

    /// @notice returns base token amount
    function getBaseTokenAmount() public view returns (uint256) {
        return investedAmount[baseToken];
    }

    /// @notice return total profits of strategy pool
    function getTotalProfits()
        public
        view
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        )
    {
        quoteTokenYieldProfit = totalProfits.quoteTokenTradeProfit;
        baseTokenYieldProfit = totalProfits.baseTokenYieldProfit;
        quoteTokenTradeProfit = totalProfits.quoteTokenTradeProfit;
        baseTokenTradeProfit = totalProfits.baseTokenTradeProfit;
    }

    /// @notice returns the owner of strategy pool
    function owner()
        public
        view
        override(AAVEV3AdapterArbitrum, IERC5313)
        returns (address)
    {
        try poolsNFT.ownerOf(poolId) returns (address _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice returns long, hedge and config
    function getPositions()
        public
        view
        override
        returns (Position memory, Position memory)
    {
        return (long, hedge);
    }

    /// @notice return pool total value locked based on positions
    /// @dev [TVL] = quoteToken
    function getTVL() public view override returns (uint256) {
        return
            investedAmount[quoteToken] +
            calcQuoteTokenByBaseToken(long.qty, long.price) +
            calcQuoteTokenByBaseToken(hedge.qty, hedge.price);
    }

    /// @notice return long position
    function getLong()
        external
        view
        override
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        )
    {
        number = long.number;
        numberMax = long.numberMax;
        priceMin = long.priceMin;
        liquidity = long.liquidity;
        qty = long.qty;
        price = long.price;
        feeQty = long.feeQty;
        feePrice = long.feePrice;
    }

    /// @notice return hedge position
    function getHedge()
        external
        view
        override
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        )
    {
        number = hedge.number;
        numberMax = hedge.numberMax;
        priceMin = hedge.priceMin;
        liquidity = hedge.liquidity;
        qty = hedge.qty;
        price = hedge.price;
        feeQty = hedge.feeQty;
        feePrice = hedge.feePrice;
    }

    /// @notice return config of strategy
    function getConfig()
        external
        view
        override
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 averagePriceVolatility,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        )
    {
        longNumberMax = config.longNumberMax;
        hedgeNumberMax = config.hedgeNumberMax;
        averagePriceVolatility = config.averagePriceVolatility;
        extraCoef = config.extraCoef;
        returnPercentLongSell = config.returnPercentLongSell;
        returnPercentHedgeSell = config.returnPercentHedgeSell;
        returnPercentHedgeRebuy = config.returnPercentHedgeRebuy;
    }

    /// @notice returns strategy id
    function strategyId() public pure override returns (uint16) {
        return 1;
    }

    /// @notice sweep tokens from smart contract
    /// @param token address of token to sweep
    function sweep(address token, address to) public payable {
        _onlyOwner();
        if (
            token == address(getAToken(baseToken)) ||
            token == address(getAToken(quoteToken))
        ) {
            revert CantSweepYieldToken();
        }
        uint256 _balance;
        if (token == address(0)) {
            _balance = address(this).balance;
            if (_balance == 0) {
                revert ZeroETH();
            }
            (bool success, ) = payable(to).call{value: _balance}("");
            if (!success) {
                revert FailETHTransfer();
            }
        } else {
            _balance = IToken(token).balanceOf(address(this));
            if (_balance == 0) {
                revert FailTokenTransfer(token);
            }
            IToken(token).safeTransfer(to, _balance);
        }
    }

    receive() external payable {
        // able to receive ETH
    }
}
