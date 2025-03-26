// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IURUS, IToken, IERC5313, AggregatorV3Interface} from "src/interfaces/IURUS.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title URUS
/// @author Triple Panic Labs, CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice core logic of URUS algorithm. Ubiquitous Resources for Utilities and Securities (URUS)
/// @dev constructor is function `initURUS`
contract URUS is IURUS {
    using SafeERC20 for IToken;

    /// @dev minimum value of `longNumberMax` in `config`
    uint8 public constant MIN_LONG_NUMBER_MAX = 1;

    /// @dev minimum value of `hedgeNumberMax` in `config`
    uint8 public constant MIN_HEDGE_NUMBER_MAX = 2;

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

    constructor() {} // only for verification simplification. As constructor call initURUS()

    /// @notice constructor of URUS core
    /// @dev config of URUS can be catched from structure `Config`
    /// @dev _oracleQuoteTokenPerFeeToken and _oracleQuoteTokenPerBaseToken may be address(0). And will not calculate fees
    /// @param _oracleQuoteTokenPerFeeToken address of price oracle of `feeToken` in terms of `quoteToken`
    /// @param _oracleQuoteTokenPerBaseToken address of price oracle of `baseToken` in terms of `quoteToken`
    /// @param _feeToken address of `feeToken`
    /// @param _quoteToken address of `quoteToken`
    /// @param _baseToken address of `baseToken`
    /// @param _config config of URUS.
    function initURUS(
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _baseToken,
        address _quoteToken,
        Config memory _config
    ) public {
        require(address(quoteToken) == address(0));

        oracleQuoteTokenPerFeeToken = AggregatorV3Interface(_oracleQuoteTokenPerFeeToken);
        oracleQuoteTokenPerBaseToken = AggregatorV3Interface(_oracleQuoteTokenPerBaseToken);

        feeToken = IToken(_feeToken);
        baseToken = IToken(_baseToken);
        quoteToken = IToken(_quoteToken);

        feeConfig = FeeConfig({
            longSellFeeCoef: 1_00, // x1.00
            hedgeSellFeeCoef: 1_00, // x1.00
            hedgeRebuyFeeCoef: 1_00 // x1.00
        });

        _checkConfig(_config);
        config = _config;

        _initHelperTokensDecimals();
        _initHelperOracle();
        _initHelperCoef();
        _setHelperInvestCoefAndInitLiquidity();

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

    /// @dev initialize tokens decimals
    function _initHelperTokensDecimals() private {
        helper.feeTokenDecimals = feeToken.decimals();
        helper.baseTokenDecimals = baseToken.decimals();
        helper.quoteTokenDecimals = quoteToken.decimals();
    }

    /// @dev initialize helper of oracle
    function _initHelperOracle() private {
        helper.oracleQuoteTokenPerFeeTokenDecimals = (address(oracleQuoteTokenPerFeeToken) != address(0)) ? oracleQuoteTokenPerFeeToken.decimals() : 8;
        helper.oracleQuoteTokenPerBaseTokenDecimals = (address(oracleQuoteTokenPerBaseToken) != address(0)) ? oracleQuoteTokenPerBaseToken.decimals() : 8;
        helper.oracleQuoteTokenPerFeeTokenMultiplier = 10 ** helper.oracleQuoteTokenPerFeeTokenDecimals;
        helper.oracleQuoteTokenPerBaseTokenMultiplier = 10 ** helper.oracleQuoteTokenPerBaseTokenDecimals;
    }

    function _initHelperCoef() private {
        helper.coefMultiplier = 10 ** 2; // x1.00 = 100
        helper.percentMultiplier = 10 ** 4; // 100% = 100_00
    }

    /// @dev depends on longNumberMax, extraCoef
    function _setHelperInvestCoefAndInitLiquidity() private {
        uint256 maxLiquidity = calcMaxLiquidity();
        helper.investCoef = calcInvestCoef();
        helper.initLiquidity = (maxLiquidity * helper.coefMultiplier) / helper.investCoef;
    }

    /// @notice checks that msg.sender is owner
    /// @dev should be reinitialized in inherited contracts, or anybody can call functionality
    function _onlyOwner() internal view virtual {
        if (owner() == address(0)) { // no owner
            return;
        }
    }

    /// @dev should be reinitialized in nested contracts!
    function _onlyGateway() internal view virtual {}

    /// @dev should be reinitialized in nested contracts!
    function _onlyAgent() internal view virtual {}

    /// @dev checks config
    function _checkConfig(Config memory conf) private pure {
        require(conf.longNumberMax > 0);
        require(conf.hedgeNumberMax > 0);
        require(conf.priceVolatilityPercent > 0);
        require(conf.extraCoef > 0);
    }

    //// ONLY AGENT //////////////////////////////////////////////////////////////////////////

    /// @notice sets config of strategy pool
    /// @param conf config structure
    function setConfig(Config memory conf) public override {
        _onlyAgent();
        _checkConfig(conf);
        if (long.number > 0) {
            require(conf.longNumberMax == config.longNumberMax);
            require(conf.extraCoef == config.extraCoef);
        }
        config = conf;
        _setHelperInvestCoefAndInitLiquidity();
    }

    /// @notice sets long number max
    /// @param longNumberMax new long number max
    function setLongNumberMax(uint8 longNumberMax) public override {
        _onlyAgent();
        require(longNumberMax >= MIN_LONG_NUMBER_MAX);
        config.longNumberMax = longNumberMax;
        _setHelperInvestCoefAndInitLiquidity();
    }

    /// @notice sets hedge number max
    /// @param hedgeNumberMax new hedge number max
    function setHedgeNumberMax(uint8 hedgeNumberMax) public override {
        _onlyAgent();
        require(hedgeNumberMax >= MIN_HEDGE_NUMBER_MAX);
        config.hedgeNumberMax = hedgeNumberMax;
    }

    /// @notice sets extra coef
    /// @param extraCoef new extra coef
    function setExtraCoef(uint256 extraCoef) public override {
        _onlyAgent();
        require(extraCoef > 0);
        require(long.number == 0);
        config.extraCoef = extraCoef;
        _setHelperInvestCoefAndInitLiquidity();
    }

    /// @notice sets price volatility
    /// @dev example: priceVolatilityPercent = 1%, that means that priceVolatilityPercent = 1_00
    /// @param priceVolatilityPercent price volatility. [priceVolatilityPercent]=%
    function setPriceVolatilityPercent(uint256 priceVolatilityPercent) public override {
        _onlyAgent();
        require(priceVolatilityPercent < helper.percentMultiplier);
        config.priceVolatilityPercent = priceVolatilityPercent;
    }

    /// @notice set return for Op
    /// @dev if realRoi == 100.5%=1.005, than returnPercent == realRoi * helper.percentMultiplier
    /// @param op operation in Op enumeration
    /// @param returnPercent return scaled by helper.percentMultiplier
    function setOpReturnPercent(uint8 op, uint256 returnPercent) public override {
        _onlyAgent();
        require(returnPercent >= helper.percentMultiplier);
        if (op == uint8(Op.LONG_SELL)) {
            config.returnPercentLongSell = returnPercent;
        } else if (op == uint8(Op.HEDGE_SELL)) {
            config.returnPercentHedgeSell = returnPercent;
        } else if (op == uint8(Op.HEDGE_REBUY)) {
            config.returnPercentHedgeRebuy = returnPercent;
        } else {
            revert InvalidOp();
        }
    }

    /// @notice set fee coeficient for Op
    /// @dev if realFeeCoef = 1.61, than feeConfig = realFeeCoef * helper.feeCoeficientMultiplier
    /// @param op operation in Op enumeration
    /// @param _feeCoef fee coeficient scaled by helper.feeCoeficientMultiplier
    function setOpFeeCoef(uint8 op, uint256 _feeCoef) public override {
        _onlyAgent();
        if (op == uint8(Op.LONG_SELL)) {
            feeConfig.longSellFeeCoef = _feeCoef;
        } else if (op == uint8(Op.HEDGE_SELL)) {
            feeConfig.hedgeSellFeeCoef = _feeCoef;
        } else if (op == uint8(Op.HEDGE_REBUY)) {
            feeConfig.hedgeRebuyFeeCoef = _feeCoef;
        } else {
            revert InvalidOp();
        }
    }

    //// ONLY GATEWAY //////////////////////////////////////////////////////////////////////////

    /// @notice deposit the quote token to strategy
    /// @dev callable only by pools NFT. This made for accounting the amount of input tokens
    /// @param quoteTokenAmount raw amount of `quoteToken`
    /// @return depositedAmount quoteToken amount
    function deposit(
        uint256 quoteTokenAmount
    ) public override returns (uint256 depositedAmount) {
        _onlyGateway(); 
        quoteToken.safeTransferFrom(
            msg.sender,
            address(this),
            quoteTokenAmount
        );
        _invest(quoteTokenAmount);
        depositedAmount = _put(quoteToken, quoteTokenAmount);
    }

    /// @notice take `quoteTokenAmount` from lending, deinvest `quoteTokenAmount` and transfer it to `to`
    /// @dev callable only by pools NFT
    /// @param to address that receive the `quoteTokenAmount`
    /// @param quoteTokenAmount amount of quoteToken
    /// @return withdrawn quoteToken amount
    function withdraw(
        address to,
        uint256 quoteTokenAmount
    ) public override returns (uint256 withdrawn) {
        _onlyGateway();
        require(long.number == 0);
        withdrawn = _take(quoteToken, quoteTokenAmount);
        _divest(withdrawn);
        quoteToken.safeTransfer(to, withdrawn);
    }

    /// @notice invest amount of `quoteToken`
    /// @dev recalculates the initLiquidity
    /// @param investAmount amount of `quoteToken` to invest. Accumulates from fee
    function _invest(
        uint256 investAmount
    ) internal returns (uint256 newMaxLiquidity) {
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
        helper.initLiquidity = (newMaxLiquidity * helper.coefMultiplier) / helper.investCoef;
    }

    /// @notice divest amount of quoteToken
    /// @dev recalculate the initLiquidity
    /// @param divestAmount amount of `quoteToken` to divest
    function _divest(
        uint256 divestAmount
    ) internal returns (uint256 newMaxLiquidity) {
        uint256 maxLiqudity = calcMaxLiquidity();
        if (divestAmount <= maxLiqudity) {
            newMaxLiquidity = maxLiqudity - divestAmount;
        }
        helper.initLiquidity = (newMaxLiquidity * helper.coefMultiplier) / helper.investCoef;
    }

    /// @notice grab all assets from strategy and send it to owner
    /// @return quoteTokenAmount amount of quoteToken in exit
    /// @return baseTokenAmount amount of baseToken in exit
    function exit()
        public
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        _onlyGateway();
        quoteTokenAmount = _take(quoteToken, type(uint256).max);
        baseTokenAmount = _take(baseToken, type(uint256).max);
        uint256 quoteTokenBalance = quoteToken.balanceOf(address(this));
        uint256 baseTokenBalance = baseToken.balanceOf(address(this));
        address _owner = owner();
        if (quoteTokenBalance > 0) {
            quoteToken.safeTransfer(_owner, quoteTokenBalance);
        }
        if (baseTokenBalance > 0) {
            baseToken.safeTransfer(_owner, baseTokenBalance);
        }

        helper.initLiquidity = 0;
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
    /// @param token address of token to distribute
    /// @param profit amount of token
    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal virtual {
        if (token == baseToken) {
            totalProfits.baseTokenYieldProfit += profit;
        } else if (token == quoteToken) {
            totalProfits.quoteTokenYieldProfit += profit;
        }
        _distributeProfit(token, profit);
    }

    /// @notice distribute trade profit
    /// @param token address of token to distribute
    /// @param profit amount of token
    function _distributeTradeProfit(
        IToken token,
        uint256 profit
    ) internal virtual {
        if (token == baseToken) {
            totalProfits.baseTokenTradeProfit += profit;
        } else if (token == quoteToken) {
            totalProfits.quoteTokenTradeProfit += profit;
        }
        _distributeProfit(token, profit);
    }

    /// @notice distribute profit
    /// @dev can be reimplemented in inherited contracts
    /// @param token address of token to distribute
    /// @param profit amount of token
    function _distributeProfit(IToken token, uint256 profit) internal virtual {}

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// ITERATE SUBFUNCTIONS

    function _put(IToken tokem, uint256 amount) internal virtual returns (uint256 putAmount) {}
    
    function _take(IToken token, uint256 amount) internal virtual returns (uint256 takeAmount) {}

    function _swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) internal virtual returns (uint256 tokenOutAmount) {}

    /// @notice makes long_buy
    function long_buy()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();
        // 0. verify that liquidity limit not exceeded
        uint8 longNumber = long.number;
        require(longNumber == 0 || longNumber < long.numberMax);

        // 1.1. calculate the quote token amount
        if (longNumber == 0) {
            quoteTokenAmount = helper.initLiquidity;
        } else {
            quoteTokenAmount = (long.liquidity * config.extraCoef) / helper.coefMultiplier;
        }
        // 1.2. Take the quoteToken from lending protocol
        quoteTokenAmount = _take(quoteToken, quoteTokenAmount);
        // 2.0 Swap quoteTokenAmount to baseTokenAmount on DEX
        baseTokenAmount = _swap(quoteToken, baseToken, quoteTokenAmount);
        uint256 swapPrice = calcSwapPrice(
            quoteTokenAmount,
            baseTokenAmount
        ); // [baseTokenPrice] = quoteToken/baseToken
        if (swapPrice > calcLongPriceMin()) {
            revert BuyUpperPriceMin();
        }

        // 3.1. Update position
        if (longNumber == 0) {
            long.numberMax = config.longNumberMax;
        }
        long.number += 1;
        long.price = (long.qty * long.price + baseTokenAmount * swapPrice) / (long.qty + baseTokenAmount);
        long.qty += baseTokenAmount;
        long.liquidity += quoteTokenAmount;
        long.priceMin = calcLongPriceMin();

        // 4.1. Put baseToken to lending protocol
        baseTokenAmount = _put(baseToken, baseTokenAmount);

        // 5.1. Accumulate fees
        uint256 feeQty = (gasStart - gasleft()) * tx.gasprice; // gas * feeToken / gas = feeToken
        uint256 feePrice = getPriceQuoteTokensPerFeeToken(); // [long.feePrice] = quoteToken/feeToken
        if (feeQty > 0 && feePrice > 0) {
            long.feePrice = (long.feeQty * long.feePrice + feeQty * feePrice) / (long.feeQty + feeQty);
        }
        long.feeQty += feeQty;
        // 6.1 Emit Transmute of long buy operation
        emit Transmute(
            uint8(Op.LONG_BUY),
            quoteTokenAmount,
            baseTokenAmount,
            swapPrice,
            feeQty
        );
    }

    /// @notice makes long_sell
    function long_sell()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();
        // 0. Verify that number != 0
        require(long.number > 0);
        require(hedge.number == 0);

        // 1. Take all qty from lending protocol
        baseTokenAmount = long.qty;
        baseTokenAmount = _take(baseToken, baseTokenAmount);

        // 2.1. Swap baseTokenAmount to quoteTokenAmount
        quoteTokenAmount = _swap(baseToken, quoteToken, baseTokenAmount);
        // 2.2. Calculate threshold and longSellPriceThreshold
        (uint256 quoteTokenAmountThreshold, ) = calcLongSellThreshold();
        if (quoteTokenAmount <= quoteTokenAmountThreshold) {
            revert NotProfitableLongSell();
        }

        // 3.0. Calculate and distribute profit
        uint256 profitPlusFees = quoteTokenAmount - long.liquidity;
        quoteTokenAmount -= profitPlusFees;
        _distributeTradeProfit(quoteToken, profitPlusFees);

        // 4.0 Put the rest of `quouteToken` to lending protocol
        quoteTokenAmount = _put(quoteToken, quoteTokenAmount);

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
        uint256 feeQty = (gasStart - gasleft()) * tx.gasprice; // gas * feeToken / gas = feeToken
        emit Transmute(
            uint8(Op.LONG_SELL),
            quoteTokenAmount,
            baseTokenAmount,
            calcSwapPrice(quoteTokenAmount, baseTokenAmount),
            feeQty // (gasStart - gasleft() + 50) * tx.gasprice
        );
    }

    /// @notice makes hedge_sell
    function hedge_sell()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();
        // 0. Verify that hedge_sell can be executed
        require(long.number == long.numberMax);

        uint8 hedgeNumber = hedge.number;
        uint8 hedgeNumberMaxMinusOne;
        // 1.0 Define hedge number max
        if (hedgeNumber == 0) {
            hedge.numberMax = config.hedgeNumberMax;
        }
        hedgeNumberMaxMinusOne = hedge.numberMax - 1;

        // 1.1. Define the base token amount to hedge sell
        if (hedgeNumber == 0) {
            baseTokenAmount = long.qty / (2 ** hedgeNumberMaxMinusOne);
        } else if (hedgeNumber < hedgeNumberMaxMinusOne) {
            baseTokenAmount = hedge.qty;
        } else if (hedgeNumber == hedgeNumberMaxMinusOne) {
            baseTokenAmount = long.qty;
        }
        // 1.2. Take the baseToken from lending protocol
        baseTokenAmount = _take(baseToken, baseTokenAmount);

        // 2.1 Swap the base token amount to quote token
        quoteTokenAmount = _swap(baseToken, quoteToken, baseTokenAmount);
        uint256 swapPrice = calcSwapPrice(quoteTokenAmount, baseTokenAmount); // [swapPrice] = quoteToken/baseToken

        if (hedgeNumber == 0) {
            // INITIALIZE HEDGE SELL
            (uint256 hedgeSellInitThresholdHigh, uint256 hedgeSellInitThresholdLow) = calcHedgeSellInitBounds();
            if (swapPrice > hedgeSellInitThresholdHigh || hedgeSellInitThresholdLow > swapPrice) {
                revert HedgeSellOutOfBound();
            }
            hedge.priceMin = swapPrice;
            hedge.price = swapPrice;
        } else {
            // HEDGE SELL
            (
                uint256 liquidity,
                uint256 quoteTokenAmountThreshold,
                uint256 targetPrice,
                /** uint256 hedgeSellPriceThreshold */
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
        quoteTokenAmount = _put(quoteToken, quoteTokenAmount);

        uint256 feeQty;
        if (hedgeNumber < hedgeNumberMaxMinusOne) {
            long.qty -= baseTokenAmount;
            hedge.qty += baseTokenAmount;
            hedge.liquidity += quoteTokenAmount;
            hedge.number += 1;

            feeQty = (gasStart - gasleft()) * tx.gasprice; // [feeQty] = gas * feeToken / gas = feeToken
            uint256 feePrice = getPriceBaseTokensPerFeeToken(swapPrice); // [feePrice] = baseToken/feeToken
            if (feeQty > 0 && feePrice > 0) {
                // gasStart always bigger than gasleft()
                // [hedge.feePrice] = (feeToken * (baseToken/feeToken) + feeToken * (baseToken/feeToken)) / (feeToken + feeToken) =
                //                  = (baseToken + baseToken) / feeToken = baseToken / feeToken
                hedge.feePrice = (hedge.feeQty * hedge.feePrice + feeQty * feePrice) / (hedge.feeQty + feeQty);
            }
            hedge.feeQty += feeQty;
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
            feeQty = (gasStart - gasleft()) * tx.gasprice; // [feeQty] = gas * feeToken / gas = feeToken
        }
        emit Transmute(
            uint8(Op.HEDGE_SELL),
            quoteTokenAmount,
            baseTokenAmount,
            swapPrice,
            feeQty
        );
    }

    /// @notice makes hedge_rebuy
    function hedge_rebuy()
        public
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        uint256 gasStart = gasleft();
        // 0. Verify that hedge is activated
        uint8 hedgeNumber = hedge.number;
        require(hedgeNumber > 0);

        // 1.1. Define how much to rebuy
        quoteTokenAmount = hedge.liquidity;
        // 1.2. Take base token amount
        quoteTokenAmount = _take(quoteToken, quoteTokenAmount);
        // 2.1 Swap quoteToken to baseToken
        baseTokenAmount = _swap(quoteToken, baseToken, quoteTokenAmount);
        uint256 swapPrice = calcSwapPrice(quoteTokenAmount, baseTokenAmount);
        (
            uint256 baseTokenAmountThreshold,
            /** uint256 hedgeLossInQuoteToken*/,
            uint256 hedgeLossInBaseToken,
            /** uint256 hedgeRebuyPriceThreshold*/
        ) = calcHedgeRebuyThreshold(quoteTokenAmount);
        if (baseTokenAmount <= baseTokenAmountThreshold) {
            revert NotProfitableRebuy();
        }
        uint256 hedgeBody = hedge.qty + hedgeLossInBaseToken;

        if (baseTokenAmount > hedgeBody) { // profit + fees
            uint256 profitPlusFees = baseTokenAmount - hedgeBody;
            _distributeTradeProfit(baseToken, profitPlusFees);
            baseTokenAmount -= profitPlusFees;
        }

        // 3.1. Put the baseToken to lending protocol
        baseTokenAmount = _put(baseToken, baseTokenAmount);

        long.qty += baseTokenAmount;
        long.price = calcSwapPrice(long.liquidity, long.qty);

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
        uint256 feeQty = (gasStart - gasleft()) * tx.gasprice; // [feeQty] = gas * feeToken / gas = feeToken
        emit Transmute(
            uint8(Op.HEDGE_REBUY),
            quoteTokenAmount,
            baseTokenAmount,
            swapPrice,
            feeQty
        );
    }

    /// @notice iteration of URUS algorithm
    /// @dev calls long_buy, long_sell, hedge_sell, hedge_rebuy
    /// @return iterated true if successfully operation made, false otherwise
    function iterate() public returns (bool iterated) {
        IURUS strategy = IURUS(address(this));
        if (long.number == 0) {
            // BUY
            try strategy.long_buy() {
                iterated = true;
            } catch {}
        } else if (long.number < long.numberMax) {
            // SELL
            try strategy.long_sell() {
                iterated = true;
            } catch {
                // EXTRA BUY
                try strategy.long_buy() {
                    iterated = true;
                } catch {}
            }
        } else {
            // long.number == long.numberMax
            if (hedge.number == 0) {
                // TRY SELL
                try strategy.long_sell() {
                    iterated = true;
                } catch {
                    // INIT HEDGE SELL
                    try strategy.hedge_sell() {
                        iterated = true;
                    } catch {}
                }
            } else {
                // hedge.number > 0
                // REBUY
                try strategy.hedge_rebuy() {
                    iterated = true;
                } catch {
                    // TRY HEDGE SELL
                    try strategy.hedge_sell() {
                        iterated = true;
                    } catch {}
                }
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// REBALANCE FUNCTIONS

    /// @notice first step for rebalance the positions via poolsNFT
    /// @dev called before rebalance by gateway
    /// @return baseTokenAmount base token amount that take part in rebalance
    /// @return price base token price scaled by price multuplier
    function beforeRebalance()
        external
        returns (uint256 baseTokenAmount, uint256 price)
    {
        _onlyGateway();
        require(hedge.number == 0);
        require(long.number == long.numberMax);
        if (long.qty > 0) {
            baseTokenAmount = _take(baseToken, long.qty);
            baseToken.forceApprove(msg.sender, baseTokenAmount);
            long.qty -= baseTokenAmount;
            price = long.price;
        }
    }

    /// @notice third step for rebalance the positions via poolsNFT
    /// @dev called after rebalance by poolsNFT
    function afterRebalance(uint256 baseTokenAmount, uint256 newPrice) external {
        _onlyGateway();
        if (baseTokenAmount > 0) {
            baseToken.safeTransferFrom(msg.sender, address(this), baseTokenAmount);
            baseTokenAmount = _put(baseToken, baseTokenAmount);
            long.qty = baseTokenAmount;
            long.price = newPrice;
            long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
            if (long.number == 0) {
                long.number = 1;
                long.numberMax = 1;
                long.priceMin = calcLongPriceMin();
            }
        } else {
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
        helper.initLiquidity = (long.liquidity * helper.coefMultiplier) / helper.investCoef;
    }

    /// @notice dip rebalance mechanism
    /// @dev executed by gateway.
    /// @dev dip baseToken, if you completely sure that you earn baseToken for free
    /// @param tokenAmount amount of quote token
    function dip(address token, uint256 tokenAmount) external override {
        _onlyGateway();
        require(long.number == long.numberMax);
        require(hedge.number == 0);
        IToken(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        uint256 baseTokenAmount;
        uint256 swapPrice;
        if (token == address(quoteToken)) {
            baseTokenAmount = _swap(quoteToken, baseToken, tokenAmount);
            swapPrice = calcSwapPrice(tokenAmount, baseTokenAmount);
            ( ,uint256 thresholdLow) = calcHedgeSellInitBounds();
            if (swapPrice >= thresholdLow) {
                revert DipUpperThreshold();
            }
            _invest(tokenAmount);
        } else if (token == address(baseToken)) {
            baseTokenAmount = tokenAmount;
            // swapPrice = 0;
            // no invest, as no quote token is surplused
        } else {
            revert ();
        }
        baseTokenAmount = _put(baseToken, baseTokenAmount);
        long.price = ((long.qty * long.price) + (baseTokenAmount * swapPrice)) / (long.qty + baseTokenAmount);
        long.qty += baseTokenAmount;
        long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// PRICES

    /// @notice returns `baseToken` price in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/baseToken
    function getPriceQuoteTokenPerBaseToken()
        public
        view
        returns (uint256 price)
    {
        if (address(oracleQuoteTokenPerBaseToken) != address(0)) {
            (, int256 answer, , , ) = oracleQuoteTokenPerBaseToken.latestRoundData();
            price = uint256(answer);
        } else {
            if ((long.qty + hedge.qty) > 0) {
                price = (long.qty * long.price + hedge.qty * hedge.price) / (long.qty + hedge.qty);
            }
        }
    }

    /// @notice returns price of `feeToken` in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/feeToken
    function getPriceQuoteTokensPerFeeToken()
        public
        view
        returns (uint256 price)
    {
        if (address(oracleQuoteTokenPerFeeToken) != address(0)) {
            (, int256 answer, , , ) = oracleQuoteTokenPerFeeToken.latestRoundData();
            price = uint256(answer);
        }
    }

    /// @notice returns price of `feeToken` in terms of `baseToken`
    /// @dev dimention [price]= baseToken/feeToken
    function getPriceBaseTokensPerFeeToken(
        uint256 quoteTokenPerBaseTokenPrice
    ) public view returns (uint256 price) {
        if (address(oracleQuoteTokenPerFeeToken) != address(0)) {
            (, int256 answer, , , ) = oracleQuoteTokenPerFeeToken.latestRoundData();
            // [price] = quoteToken / feeToken * (1 / (quoteToken / baseToken)) = baseToken / feeToken
            price = (uint256(answer) * helper.oracleQuoteTokenPerBaseTokenMultiplier) / quoteTokenPerBaseTokenPrice;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// CALCULATE FUNCTIONS

    /// @notice calculate max liquidity that can be used for buying
    /// @dev q_n = q_1 * investCoef / coefMultiplier
    function calcMaxLiquidity() public view override returns (uint256) {
        return (helper.initLiquidity * helper.investCoef) / helper.coefMultiplier;
    }

    /// @notice calculates invest coeficient
    /// @dev q_n = (e+1) ^ (n-1) * q_1 => investCoef = (e+1)^(n-1)
    /// @dev invest coef depends on config.longNumberMax and config.extraCoef
    function calcInvestCoef() public view override returns (uint256 investCoef) {
        uint8 exponent = config.longNumberMax - 1;
        uint256 multiplier = helper.coefMultiplier;
        if (exponent >= 2) {
            investCoef = ((config.extraCoef + multiplier) ** exponent) / (multiplier ** (exponent - 1));
        } else if (exponent == 1) {
            investCoef = config.extraCoef + multiplier;
        } else {
            // exponent == 0
            investCoef = multiplier;
        }
    }

    /// @notice calculates the price of `baseToken` in terms of `quoteToken` based on `quoteTokenAmount` and `baseTokenAmount`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @param baseTokenAmount amoint of `baseToken`
    /// @return price the price of 1 `baseToken`. Dimension: [price] = quoteToken/baseToken
    function calcSwapPrice(
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    ) public view override returns (uint256 price) {
        uint8 bd = helper.baseTokenDecimals;
        uint8 qd = helper.quoteTokenDecimals;
        uint8 pd = helper.oracleQuoteTokenPerBaseTokenDecimals;
        if (pd >= qd) {
            price = (quoteTokenAmount * (10 ** (bd + pd - qd))) / baseTokenAmount;
        } else {
            price = (quoteTokenAmount * (10 ** bd)) / (baseTokenAmount * (10 ** (qd - pd)));
        }
    }

    /// @notice calculate min price for long position
    function calcLongPriceMin() public view returns (uint256) {
        if (long.number == 0) {
            return type(uint256).max;
        } else {
            return (long.price - ((long.price * config.priceVolatilityPercent) / helper.percentMultiplier));
        }
    }

    /// @notice calculates long sell thresholds
    /// @return quoteTokenAmountThreshold threshold amount of `quoteToken`
    /// @return longSellPriceThreshold threshold price to execute swap
    function calcLongSellThreshold() public view override
        returns (
            uint256 quoteTokenAmountThreshold,
            uint256 longSellPriceThreshold
        )
    {
        uint256 feeQty = (long.feeQty * feeConfig.longSellFeeCoef) / helper.coefMultiplier;
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
        quoteTokenAmountThreshold = ((long.liquidity + fees) * config.returnPercentLongSell) / helper.percentMultiplier;
        longSellPriceThreshold = calcSwapPrice(quoteTokenAmountThreshold, long.qty);
    }

    /// @notice calculates target hedge price for undersell
    /// @param hedgeNumber the number of hedge
    /// @param priceMin minimum price, when undersell happened on hedgeNumber==0
    /// @param priceMax maximum price, where are targeting to
    function calcTargetHedgePrice(
        uint8 hedgeNumber,
        uint256 priceMin,
        uint256 priceMax
    ) public view override returns (uint256 targetPrice) {
        uint8 hedgeNumberMax = hedge.numberMax;
        if (hedgeNumberMax == 1) {
            targetPrice = priceMax;
        } else {
            targetPrice = priceMin + ((priceMax - priceMin) * hedgeNumber) / (hedgeNumberMax - 1);
        }
    }

    /// @notice calculates hedge sell thresholds bounds for initialization of hedge position
    function calcHedgeSellInitBounds() public view override returns (uint256 thresholdHigh, uint256 thresholdLow) {
        /**
         * Visual of delta with hedgeNumberMax = 3
         *             hedge.priceMin             long.price  longSellPrice
         *     |------------|------------|------------|------------|------------> price
         *                price_1      price_2     price_3    price_3+delta
         *                   <-----------><-----------><----------->
         *                       delta        delta        delta
         *                   <------------------------>
         *                            2 * delta
         * 
         *  delta := longSellPrice - long.price
         *  thresholdLow := long.price - 2 * delta 
         *  Generalize:
         *      thresholdLow := long.price - (hedgeNumberMax - 1) * delta 
         *  Let thresholdHigh := long.price - (delta / 2)
         */
        (, uint256 longSellPrice) = calcLongSellThreshold();
        thresholdHigh = (long.price - ((longSellPrice - long.price) / 2));
        thresholdLow = (long.price - ((config.hedgeNumberMax - 1) * (longSellPrice - long.price)));
    }

    /// @notice calculates hedge sell threshold
    /// @param baseTokenAmount base token amount
    function calcHedgeSellThreshold(uint256 baseTokenAmount) public view override
        returns (
            uint256 liquidity,
            uint256 quoteTokenAmountThreshold,
            uint256 targetPrice,
            uint256 hedgeSellPriceThreshold
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
        uint256 feeQty = (long.feeQty * feeConfig.hedgeSellFeeCoef) / helper.coefMultiplier;
        uint256 fees = (2 * calcQuoteTokenByFeeToken(feeQty, long.feePrice)) / (hedge.numberMax - 1); // [fees] = quoteToken
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
        quoteTokenAmountThreshold = ((liquidity + fees) * config.returnPercentHedgeSell) / helper.percentMultiplier;
        hedgeSellPriceThreshold = calcSwapPrice(quoteTokenAmountThreshold, baseTokenAmount);
    }

    /// @notice calculates hedge rebuy threshold
    /// @param quoteTokenAmount quote token amount
    function calcHedgeRebuyThreshold(uint256 quoteTokenAmount) public view override
        returns (
            uint256 baseTokenAmountThreshold,
            uint256 hedgeLossInQuoteToken,
            uint256 hedgeLossInBaseToken,
            uint256 hedgeRebuyPriceThreshold
        )
    {
        /**
         * FORMULA for rebuy
         *      h.q + hedgeLoss + fees + profit <= baseTokenAmount
         */
        /**
         * Visual of hedge rebuy criteria
         * |--------|------------|------------------|--------------------------|---------------------|-------------> BaseToken
         *         h.q      h.q+hedgeLoss    h.q+hedgeLoss+fee     h.q+hedgeLoss+fee+profit   baseTokenAmount
         */
        /**
         * Rebuy fee:
         *      hedgeRebuyFee = estimation for 1 execution of rebuy as sum of all hedge sell fees divided to hedge.number + sum of all hedge sell fees =
         *                    = hedgeSellFees / hedge.number + hedgeSellFees
         */
        uint256 feeQty = (hedge.feeQty * feeConfig.hedgeRebuyFeeCoef) / helper.coefMultiplier;
        uint256 hedgeSellFees; // [hedgeSellFees] = baseToken
        if (feeToken == baseToken) {
            hedgeSellFees = feeQty;
        } else {
            hedgeSellFees = calcBaseTokenByFeeToken(feeQty, hedge.feePrice);
        }
        uint256 hedgeRebuyFee = hedgeSellFees / hedge.number;
        hedgeLossInQuoteToken = calcQuoteTokenByBaseToken(hedge.qty, (long.price - hedge.price));
        hedgeLossInBaseToken = calcBaseTokenByQuoteToken(hedgeLossInQuoteToken, hedge.price);
        baseTokenAmountThreshold = ((hedge.qty + hedgeLossInBaseToken + hedgeSellFees + hedgeRebuyFee) * config.returnPercentHedgeRebuy) / helper.percentMultiplier;
        hedgeRebuyPriceThreshold = calcSwapPrice(
            quoteTokenAmount,
            baseTokenAmountThreshold
        );
    }

    //// VIEW FUNCTION FOR METRICS /////////////////////////////////////////////////////////////////////

    /// @notice calculates hedge sell threshold
    function calcHedgeSellThreshold() public view override
        returns (
            uint256 liquidity,
            uint256 quoteTokenAmountThreshold,
            uint256 targetPrice,
            uint256 hedgeSellPriceThreshold
        )
    {
        uint256 baseTokenAmount;
        uint8 hedgeNumber = hedge.number;
        uint8 hedgeNumberMaxMinusOne;
        if (hedge.numberMax > 0) {
            hedgeNumberMaxMinusOne = hedge.numberMax - 1;
        } else {
            hedgeNumberMaxMinusOne = config.hedgeNumberMax - 1;
        }

        if (hedgeNumber == 0) {
            baseTokenAmount = long.qty / (2 ** hedgeNumberMaxMinusOne);
        } else if (hedgeNumber < hedgeNumberMaxMinusOne) {
            baseTokenAmount = hedge.qty;
        } else if (hedgeNumber == hedgeNumberMaxMinusOne) {
            baseTokenAmount = long.qty;
        }
        return calcHedgeSellThreshold(baseTokenAmount);
    }

    /// @notice calculates target price for frontend
    function calcTargetHedgePrice() public view override returns (uint256 targetPrice) {
        targetPrice = calcTargetHedgePrice(hedge.number, hedge.priceMin, long.price);
    }

    /// @notice calculates rebuy threshold
    function calcHedgeRebuyThreshold() public view override
        returns (
            uint256 baseTokenAmountThreshold,
            uint256 hedgeLossInQuoteToken,
            uint256 hedgeLossInBaseToken,
            uint256 hedgeRebuyPriceThreshold
        )
    {
        return calcHedgeRebuyThreshold(hedge.liquidity);
    }

    //// PRICE CALCULATIONS ////////////////////////////////////////////////////////////////////////////

    /// @notice calculates baseTokenAmount in terms of `quoteToken` with `baseTokenPrice`
    /// @dev quoteTokenAmount = baseTokenAmount * quoteTokenPerBaseTokenPrice
    /// @dev [quoteTokenAmount] = baseToken * quoteToken / baseToken = quoteToken
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
            quoteTokenAmount = (baseTokenAmount * quoteTokenPerBaseTokenPrice * (10 ** (qd - bd))) / helper.oracleQuoteTokenPerBaseTokenMultiplier;
        } else {
            quoteTokenAmount = (baseTokenAmount * quoteTokenPerBaseTokenPrice) / (helper.oracleQuoteTokenPerBaseTokenMultiplier * (10 ** (bd - qd)));
        }
    }

    /// @notice calculate the feeTokenAmount in terms of `quoteToken`
    /// @dev quoteTokenAmount = feeTokenAmount * quoteTokenPerFeeTokenPrice
    /// @dev [quoteTokenAmount] = feeToken * quoteToken / feeToken = quoteToken
    /// @param feeTokenAmount amount of `feeToken`. [feeTokenAmount]=feeToken
    /// @param quoteTokenPerFeeTokenPrice price of quoteToken per feeToken. [priceQuoteTokenPerFeeToken] = quoteToken/feeToken
    function calcQuoteTokenByFeeToken(
        uint256 feeTokenAmount,
        uint256 quoteTokenPerFeeTokenPrice
    ) public view returns (uint256 quoteTokenAmount) {
        uint8 qd = helper.quoteTokenDecimals;
        uint8 fd = helper.feeTokenDecimals;
        if (qd >= fd) {
            quoteTokenAmount = (feeTokenAmount * quoteTokenPerFeeTokenPrice * (10 ** (qd - fd))) / helper.oracleQuoteTokenPerFeeTokenMultiplier;
        } else {
            quoteTokenAmount = (feeTokenAmount * quoteTokenPerFeeTokenPrice) / (helper.oracleQuoteTokenPerFeeTokenMultiplier * (10 ** (fd - qd)));
        }
    }

    /// @notice calculate feeTokenAmount in terms of `baseToken`
    /// @dev baseTokenAmount = feeTokenAmount * baseTokenPerFeeTokenPrice
    /// @dev [baseTokenAmount] = feeToken * baseToken / feeToken = baseToken
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
            baseTokenAmount = (feeTokenAmount * baseTokenPerFeeTokenPrice * (10 ** (bd - fd))) / helper.oracleQuoteTokenPerFeeTokenMultiplier;
        } else {
            baseTokenAmount = (feeTokenAmount * baseTokenPerFeeTokenPrice) / (helper.oracleQuoteTokenPerFeeTokenMultiplier * (10 ** (fd - bd)));
        }
    }
    
    /// @notice calculate feeTokenAmount in terms of `baseToken`
    /// @dev baseTokenAmount = quoteTokenAmount / quoteTokenPerBaseTokenPrice
    /// @dev [baseTokenAmount] = quoteToken / (quoteToken / baseToken) = baseToken
    /// @param quoteTokenAmount amount of `feeToken`. [feeTokenAmount]=feeToken
    /// @param quoteTokenPerBaseTokenPrice price of baseToken per feeToken. [baseTokenPerFeeTokenPrice]=baseToken/feeToken
    /// @return baseTokenAmount amount of `baseToken`
    function calcBaseTokenByQuoteToken(
        uint256 quoteTokenAmount,
        uint256 quoteTokenPerBaseTokenPrice
    ) public view returns (uint256 baseTokenAmount) {
        uint8 bd = helper.baseTokenDecimals;
        uint8 qd = helper.quoteTokenDecimals;
        if (bd >= qd) {
            baseTokenAmount = (quoteTokenAmount * helper.oracleQuoteTokenPerBaseTokenMultiplier * (10 ** (bd - qd))) / quoteTokenPerBaseTokenPrice;
        } else {
            baseTokenAmount = (quoteTokenAmount * helper.oracleQuoteTokenPerBaseTokenMultiplier) / (quoteTokenPerBaseTokenPrice * (10 ** (qd - bd)));
        }
    }

    /// @notice return thresholds
    function getThresholds() 
        external
        view 
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
        ) {
        if (long.number == 0) {
            return (0,0,0,0,0,0,0,0,0,0,0);
        } 
        if (long.number > 0 && hedge.number == 0) {
            longBuyPriceMin = calcLongPriceMin();
            (longSellQuoteTokenAmountThreshold, longSellSwapPriceThreshold) = calcLongSellThreshold();
        }
        if (long.number == long.numberMax && hedge.number == 0) {
            (hedgeSellInitPriceThresholdHigh, hedgeSellInitPriceThresholdLow) = calcHedgeSellInitBounds();
        } 
        if (hedge.number > 0) {
            (
                hedgeSellLiquidity,
                hedgeSellQuoteTokenAmountThreshold,
                hedgeSellTargetPrice,
                hedgeSellSwapPriceThreshold
            ) = calcHedgeSellThreshold();
            (
                hedgeRebuyBaseTokenAmountThreshold,
                ,
                ,
                hedgeRebuySwapPriceThreshold
            ) = calcHedgeRebuyThreshold();
        }
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
        priceMin = calcLongPriceMin();
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
        public
        view
        override
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 extraCoef,
            uint256 priceVolatilityPercent,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        )
    {
        longNumberMax = config.longNumberMax;
        hedgeNumberMax = config.hedgeNumberMax;
        extraCoef = config.extraCoef;
        priceVolatilityPercent = config.priceVolatilityPercent;
        returnPercentLongSell = config.returnPercentLongSell;
        returnPercentHedgeSell = config.returnPercentHedgeSell;
        returnPercentHedgeRebuy = config.returnPercentHedgeRebuy;
    }

    /// @notice return fee config of strategy
    function getFeeConfig()
        public
        view
        override
        returns (
            uint256 longSellFeeCoef,
            uint256 hedgeSellFeeCoef,
            uint256 hedgeRebuyFeeCoef
        )
    {
        longSellFeeCoef = feeConfig.longSellFeeCoef;
        hedgeSellFeeCoef = feeConfig.hedgeSellFeeCoef;
        hedgeRebuyFeeCoef = feeConfig.hedgeRebuyFeeCoef;
    }

    /// @notice returns the owner of strategy pool
    /// @dev may be reimplemented in inherrited contracts
    function owner()
        public
        view
        virtual
        override(IERC5313)
        returns (address)
    {
        return address(0); // no owner
    }

    receive() external payable {
        // able to receive ETH. May be inherrited and reimplemented
    }

}