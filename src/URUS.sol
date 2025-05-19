// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IURUS, IToken, IERC5313, IOracle } from "src/interfaces/IURUS.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

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

    /// @dev timestamp of deployment
    uint256 public startTimestamp;

    /// @dev price feed of fee token. [oracle] = quoteToken/feeToken
    ///      for Ethereum mainnet = ETH, for BSC = BNB, Optimism = ETH, etc
    IOracle public oracleQuoteTokenPerFeeToken;

    /// @dev price feed of base token. [oracle] = quoteToken/baseToken
    IOracle public oracleQuoteTokenPerBaseToken;

    /// @dev set of helper params
    HelperData public helper;

    /// @dev runtime of URUS
    Runtime public runtime;

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

    /// @dev profits of pool
    Profits public profits;

    /// @dev total profits of pool
    Profits public totalProfits;

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

        oracleQuoteTokenPerFeeToken = IOracle(_oracleQuoteTokenPerFeeToken);
        oracleQuoteTokenPerBaseToken = IOracle(_oracleQuoteTokenPerBaseToken);

        feeToken = IToken(_feeToken);
        baseToken = IToken(_baseToken);
        quoteToken = IToken(_quoteToken);

        // default fee config
        feeConfig = FeeConfig({
            longSellFeeCoef: 0, // x0
            hedgeSellFeeCoef: 0, // x0
            hedgeRebuyFeeCoef: 0 // x0
        });

        if (!checkConfig(_config)) {
            revert InvalidConfig();
        }
        config = _config;

        _initHelperTokensDecimals();
        _initHelperOracle();
        _initHelperCoef();
        _setInvestCoefAndInitLiquidity();

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
    function _setInvestCoefAndInitLiquidity() private {
        uint256 maxLiquidity = evalMaxLiquidity();
        runtime.investCoef = evalInvestCoef();
        runtime.initLiquidity = (maxLiquidity * helper.coefMultiplier) / runtime.investCoef;
    }

    /// @notice calculate max liquidity that can be used for buying
    /// @dev q_n = q_1 * investCoef / coefMultiplier
    function evalMaxLiquidity() public view override returns (uint256) {
        return (runtime.initLiquidity * runtime.investCoef) / helper.coefMultiplier;
    }

    /// @notice calculates invest coeficient
    /// @dev q_n = (e+1) ^ (n-1) * q_1 => investCoef = (e+1)^(n-1)
    /// @dev invest coef depends on config.longNumberMax and config.extraCoef
    function evalInvestCoef() public view override returns (uint256 investCoef) {
        uint8 exponent = config.longNumberMax - 1;
        uint256 multiplier = helper.coefMultiplier;
        if (exponent >= 2) {
            investCoef = ((config.extraCoef + multiplier) ** exponent) / (multiplier ** (exponent - 1));
        } else if (exponent == 1) {
            investCoef = config.extraCoef + multiplier;
        } else { // exponent == 0
            investCoef = multiplier;
        }
    }

    /// @dev checks config
    function checkConfig(Config memory conf) public pure override virtual returns (bool) {
        if (
            conf.longNumberMax >= MIN_LONG_NUMBER_MAX && 
            conf.hedgeNumberMax >= MIN_HEDGE_NUMBER_MAX &&
            conf.extraCoef > 0
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// ONLY AGENT //////////////////////////////////////////////////////////////////////////

    /// @notice sets oracle for URUS
    /// @param _oracleQuoteTokenPerFeeToken oracle for quote token per fee token
    /// @param _oracleQuoteTokenPerBaseToken oracle for quote token per base token
    function setOracles(address _oracleQuoteTokenPerFeeToken, address _oracleQuoteTokenPerBaseToken) public virtual override {
        oracleQuoteTokenPerFeeToken = IOracle(_oracleQuoteTokenPerFeeToken);
        oracleQuoteTokenPerBaseToken = IOracle(_oracleQuoteTokenPerBaseToken);
        _initHelperOracle();
    }

    /// @notice sets config for URUS
    /// @param conf config structure
    function setConfig(Config memory conf) public virtual override {
        if (!checkConfig(conf)) {
            revert InvalidConfig();
        }
        if (long.number > 0) {
            require(conf.longNumberMax == config.longNumberMax);
            require(conf.extraCoef == config.extraCoef);
        }
        config = conf;
        _setInvestCoefAndInitLiquidity();
    }

    /// @notice sets long number max
    /// @param longNumberMax new long number max
    function setLongNumberMax(uint8 longNumberMax) public virtual override {
        require(longNumberMax >= MIN_LONG_NUMBER_MAX);
        config.longNumberMax = longNumberMax;
        _setInvestCoefAndInitLiquidity();
    }

    /// @notice sets hedge number max
    /// @param hedgeNumberMax new hedge number max
    function setHedgeNumberMax(uint8 hedgeNumberMax) public virtual override {
        require(hedgeNumberMax >= MIN_HEDGE_NUMBER_MAX);
        config.hedgeNumberMax = hedgeNumberMax;
    }

    /// @notice sets extra coef
    /// @param extraCoef new extra coef
    function setExtraCoef(uint256 extraCoef) public virtual override {
        require(extraCoef > 0);
        require(long.number == 0);
        config.extraCoef = extraCoef;
        _setInvestCoefAndInitLiquidity();
    }

    /// @notice sets price volatility
    /// @dev example: priceVolatilityPercent = 1%, that means that priceVolatilityPercent = 1_00
    /// @param priceVolatilityPercent price volatility. [priceVolatilityPercent]=%
    function setPriceVolatilityPercent(uint256 priceVolatilityPercent) public virtual override {
        require(priceVolatilityPercent < helper.percentMultiplier);
        config.priceVolatilityPercent = priceVolatilityPercent;
    }

    /// @notice set return for Op
    /// @dev if realRoi == 100.5%=1.005, than returnPercent == realRoi * helper.percentMultiplier
    /// @param op operation in Op enumeration
    /// @param returnPercent return scaled by helper.percentMultiplier
    function setOpReturnPercent(uint8 op, uint256 returnPercent) public virtual override {
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
    /// @param feeCoef fee coeficient scaled by helper.feeCoeficientMultiplier
    function setOpFeeCoef(uint8 op, uint256 feeCoef) public virtual override {
        if (op == uint8(Op.LONG_SELL)) {
            feeConfig.longSellFeeCoef = feeCoef;
        } else if (op == uint8(Op.HEDGE_SELL)) {
            feeConfig.hedgeSellFeeCoef = feeCoef;
        } else if (op == uint8(Op.HEDGE_REBUY)) {
            feeConfig.hedgeRebuyFeeCoef = feeCoef;
        } else {
            revert InvalidOp();
        }
    }

    //// ONLY GATEWAY //////////////////////////////////////////////////////////////////////////

    /// @notice deposit the quote token to URUS
    /// @param quoteTokenAmount amount of quote token
    function deposit(
        uint256 quoteTokenAmount
    ) public virtual override returns (uint256) {
        if (hedge.number > 0) {
            revert Hedged();
        }
        quoteToken.safeTransferFrom(msg.sender, address(this), quoteTokenAmount);
        if (long.number == 0) {
            startTimestamp = block.timestamp;
            quoteTokenAmount = _put(quoteToken, quoteTokenAmount);
        } else {
            uint256 baseTokenAmount = _swap(quoteToken, baseToken, quoteTokenAmount);
            baseTokenAmount = _put(baseToken, baseTokenAmount);

            uint256 swapPrice = calcSwapPrice(quoteTokenAmount, baseTokenAmount);
            quoteTokenAmount = calcQuoteTokenByBaseToken(baseTokenAmount, swapPrice);
    
            long.price = ((long.qty * long.price) + (baseTokenAmount * swapPrice)) / (long.qty + baseTokenAmount);
            long.qty += baseTokenAmount;
            long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
        }
        _invest(quoteTokenAmount);
        return quoteTokenAmount;
    }

    /// @notice deposit the base token to URUS
    /// @param baseTokenAmount amount of `baseToken`
    /// @param baseTokenPrice price of base token amount
    function deposit2(
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) public virtual override returns (uint256) {
        if (hedge.number > 0) {
            revert Hedged();
        }
        baseToken.safeTransferFrom(msg.sender, address(this), baseTokenAmount);
        baseTokenAmount = _put(baseToken, baseTokenAmount);
        long.price = ((long.qty * long.price) + (baseTokenAmount * baseTokenPrice)) / (long.qty + baseTokenAmount);
        long.qty += baseTokenAmount;
        long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
        uint256 quoteTokenAmount;
        if (long.number == 0) {
            startTimestamp = block.timestamp;
            long.number = 1;
            long.numberMax = 1;
            quoteTokenAmount = calcQuoteTokenByBaseToken(long.qty, long.price);
        } else { 
            quoteTokenAmount = calcQuoteTokenByBaseToken(baseTokenAmount, baseTokenPrice);
        }
        _invest(quoteTokenAmount);
        long.priceMin = calcLongPriceMin();
        return baseTokenAmount;
    }

    /// @notice take `quoteTokenAmount` from lending, deinvest `quoteTokenAmount` and transfer it to `to`
    /// @dev withdrawable only when not long.number == 0
    /// @param to address that receive the `quoteTokenAmount`
    /// @param quoteTokenAmount amount of quoteToken
    /// @return withdrawn quoteToken amount
    function withdraw(
        address to,
        uint256 quoteTokenAmount
    ) public virtual override returns (uint256 withdrawn) {
        if (long.number > 0) {
            revert Longed();
        }
        withdrawn = _take(quoteToken, quoteTokenAmount);
        _divest(withdrawn);
        quoteToken.safeTransfer(to, withdrawn);
    }

    /// @notice take `baseTokenAmount` from lending, deinvest `baseTokenAmount` and transfer it to `to`
    /// @dev withdrawable only when long.number == long.numberMax and not hedged
    /// @param to address that receive the `baseTokenAmount`
    /// @param baseTokenAmount amount of baseToken
    function withdraw2(
        address to,
        uint256 baseTokenAmount
    ) public virtual override returns (uint256 withdrawn) {
        if (long.number != long.numberMax) {
            revert NotLongNumberMax();
        }
        if (hedge.number > 0) {
            revert Hedged();
        }
        if (baseTokenAmount > long.qty) {
            baseTokenAmount = long.qty;
        }
        withdrawn = _take(baseToken, baseTokenAmount);
        baseToken.safeTransfer(to, withdrawn);
        long.qty -= withdrawn;
        long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
        _divest(calcQuoteTokenByBaseToken(baseTokenAmount, long.price));
    }

    /// @notice invest amount of `quoteToken`
    /// @dev recalculates the initLiquidity
    /// @param investAmount amount of `quoteToken` to invest. Accumulates from fee
    function _invest(
        uint256 investAmount
    ) internal virtual returns (uint256 newMaxLiquidity) {
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
        newMaxLiquidity = evalMaxLiquidity() + investAmount;
        runtime.initLiquidity = (newMaxLiquidity * helper.coefMultiplier) / runtime.investCoef;
    }

    /// @notice divest amount of quoteToken
    /// @dev recalculate the initLiquidity
    /// @param divestAmount amount of `quoteToken` to divest
    function _divest(
        uint256 divestAmount
    ) internal virtual returns (uint256 newMaxLiquidity) {
        uint256 maxLiqudity = evalMaxLiquidity();
        if (divestAmount <= maxLiqudity) {
            newMaxLiquidity = maxLiqudity - divestAmount;
        }
        runtime.initLiquidity = (newMaxLiquidity * helper.coefMultiplier) / runtime.investCoef;
    }

    /// @notice grab all assets from strategy and send it to owner
    /// @return quoteTokenAmount amount of quoteToken in exit
    /// @return baseTokenAmount amount of baseToken in exit
    function exit() public virtual override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
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
        runtime.initLiquidity = 0;
        runtime.liquidity = 0;
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
        startTimestamp = 0;
        profits = Profits({
            baseTokenYieldProfit: 0,
            quoteTokenYieldProfit: 0,
            baseTokenTradeProfit: 0,
            quoteTokenTradeProfit: 0
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
            profits.baseTokenYieldProfit += profit;
            totalProfits.baseTokenYieldProfit += profit;
        } else if (token == quoteToken) {
            profits.quoteTokenYieldProfit += profit;
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
            profits.baseTokenTradeProfit += profit;
            totalProfits.baseTokenTradeProfit += profit;
        } else if (token == quoteToken) {
            profits.quoteTokenTradeProfit += profit;
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

    function getPendingYield(IToken token) public view virtual returns (uint256 pendingYield) {}

    /// @notice makes long_buy
    function long_buy() public virtual override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        uint256 gasStart = gasleft();
        // 0. verify that liquidity limit not exceeded
        uint8 longNumber = long.number;
        require(longNumber == 0 || longNumber < long.numberMax);

        // 1.1. calculate the quote token amount
        if (longNumber == 0) {
            quoteTokenAmount = runtime.initLiquidity;   
        } else {
            quoteTokenAmount = (runtime.liquidity * config.extraCoef) / helper.coefMultiplier;
        }
        runtime.liquidity += quoteTokenAmount;

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
        long.price = ((long.qty * long.price) + (baseTokenAmount * swapPrice)) / (long.qty + baseTokenAmount);
        long.qty += baseTokenAmount;
        long.liquidity = calcQuoteTokenByBaseToken(long.qty, long.price);
        long.priceMin = calcLongPriceMin();

        // 4.1. Put baseToken to lending protocol
        baseTokenAmount = _put(baseToken, baseTokenAmount);

        // 5.1. Accumulate fees
        uint256 feeQty = (gasStart - gasleft()) * tx.gasprice; // gas * feeToken / gas = feeToken
        uint256 feePrice = getPriceQuoteTokenPerFeeToken(); // [long.feePrice] = quoteToken/feeToken
        if (feeQty > 0 && feePrice > 0) {
            long.feePrice = ((long.feeQty * long.feePrice) + (feeQty * feePrice)) / (long.feeQty + feeQty);
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
    function long_sell() public override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        uint256 gasStart = gasleft();
        // 0. Verify that number != 0
        if (long.number == 0) {
            revert NotLonged();
        }
        if (hedge.number > 0) {
            revert Hedged();
        }

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
        runtime.liquidity = 0;
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
            feeQty
        );
    }

    /// @notice makes hedge_sell
    function hedge_sell() public override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        uint256 gasStart = gasleft();
        // 0. Verify that hedge_sell can be executed
        if (long.number != long.numberMax) {
            revert NotLongNumberMax();
        }

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
            uint256 feePrice = getPriceBaseTokenPerFeeToken(swapPrice); // [feePrice] = baseToken/feeToken
            if (feeQty > 0 && feePrice > 0) {
                // gasStart always bigger than gasleft()
                // [hedge.feePrice] = (feeToken * (baseToken/feeToken) + feeToken * (baseToken/feeToken)) / (feeToken + feeToken) =
                //                  = (baseToken + baseToken) / feeToken = baseToken / feeToken
                hedge.feePrice = ((hedge.feeQty * hedge.feePrice) + (feeQty * feePrice)) / (hedge.feeQty + feeQty);
            }
            hedge.feeQty += feeQty;
        } else if (hedgeNumber == hedgeNumberMaxMinusOne) {
            runtime.liquidity = 0;
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
    function hedge_rebuy() public override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        uint256 gasStart = gasleft();
        // 0. Verify that hedge is activated
        if (hedge.number == 0) {
            revert NotHedged();
        }

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
    function microOps() public returns (bool iterated) {
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
    //// PRICES

    /// @notice returns `baseToken` price in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/baseToken
    function getPriceQuoteTokenPerBaseToken() public view virtual override returns (uint256 price) {
        if (address(oracleQuoteTokenPerBaseToken) != address(0)) {
            try oracleQuoteTokenPerBaseToken.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
                price = uint256(answer);
            } catch {
                price = 0;
            }
        }
    }

    /// @notice returns price of `feeToken` in terms of `quoteToken`
    /// @dev dimention [price]=quoteToken/feeToken
    function getPriceQuoteTokenPerFeeToken() public view virtual override returns (uint256 price) {
        if (address(oracleQuoteTokenPerFeeToken) != address(0)) {
            try oracleQuoteTokenPerFeeToken.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
                price = uint256(answer);
            } catch {
                price = 0;
            }
        }
    }

    /// @notice returns price of `feeToken` in terms of `baseToken`
    /// @dev dimention [price]= baseToken/feeToken
    function getPriceBaseTokenPerFeeToken(
        uint256 quoteTokenPerBaseTokenPrice
    ) public view virtual override returns (uint256 price) {
        if (address(oracleQuoteTokenPerFeeToken) != address(0)) {
            try oracleQuoteTokenPerFeeToken.latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
                // [price] = quoteToken / feeToken * (1 / (quoteToken / baseToken)) = baseToken / feeToken
                price = (uint256(answer) * helper.oracleQuoteTokenPerBaseTokenMultiplier) / quoteTokenPerBaseTokenPrice;
            } catch {
                price = 0;
            }
        }
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //// CALCULATE FUNCTIONS

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
        quoteTokenAmountThreshold = ((long.liquidity + buyFee + sellFee) * config.returnPercentLongSell) / helper.percentMultiplier;
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
            quoteTokenAmount = ((baseTokenAmount * quoteTokenPerBaseTokenPrice) * (10 ** (qd - bd))) / helper.oracleQuoteTokenPerBaseTokenMultiplier;
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
            quoteTokenAmount = ((feeTokenAmount * quoteTokenPerFeeTokenPrice) * (10 ** (qd - fd))) / helper.oracleQuoteTokenPerFeeTokenMultiplier;
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
            baseTokenAmount = ((feeTokenAmount * baseTokenPerFeeTokenPrice) * (10 ** (bd - fd))) / helper.oracleQuoteTokenPerFeeTokenMultiplier;
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
            baseTokenAmount = ((quoteTokenAmount * helper.oracleQuoteTokenPerBaseTokenMultiplier) * (10 ** (bd - qd))) / quoteTokenPerBaseTokenPrice;
        } else {
            baseTokenAmount = (quoteTokenAmount * helper.oracleQuoteTokenPerBaseTokenMultiplier) / (quoteTokenPerBaseTokenPrice * (10 ** (qd - bd)));
        }
    }

    /// @notice return thresholds
    function getThresholds() public view virtual
        returns (
            // long buy
            uint256 longBuyPriceMin,
            // long sell
            uint256 longSellQuoteTokenAmountThreshold,
            uint256 longSellSwapPriceThreshold,
            // init hedge sell
            uint256 hedgeSellInitPriceThresholdHigh,
            uint256 hedgeSellInitPriceThresholdLow,
            // hedge sell
            uint256 hedgeSellLiquidity,
            uint256 hedgeSellQuoteTokenAmountThreshold,
            uint256 hedgeSellTargetPrice,
            uint256 hedgeSellSwapPriceThreshold,
            // hedge rebuy
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

    /// @notice return realtime PnL of positions
    function getPnL() public view override virtual returns (PnL memory) {
        uint256 spotPrice = getPriceQuoteTokenPerBaseToken();
        return getPnL(spotPrice);
    }

    /// @notice return realtime PnL of positions based on `spotPrice`
    /// @param spotPrice spot price of base token
    /// @dev [longSellRealtimePnL] = quoteToken
    /// @dev [hedgeSellInitPnL] = quoteToken
    /// @dev [hedgeSellRealtimePnL] = quoteToken
    /// @dev [hedgeRebuyRealtimePnL] = baseToken
    function getPnL(uint256 spotPrice) public view virtual override returns (PnL memory pnl) {
        if (long.number > 0 && hedge.number == 0) {
            pnl.longSellRealtime = int256(calcQuoteTokenByBaseToken(long.qty, spotPrice)) - int256(calcQuoteTokenByBaseToken(long.qty, long.price));
            (uint256 quoteTokenAmountThreshold,) = calcLongSellThreshold();
            pnl.longSellTarget = int256(quoteTokenAmountThreshold) - int256(calcQuoteTokenByBaseToken(long.qty, long.price));
        }
        if (long.number == long.numberMax && hedge.number == 0) {
            uint256 baseTokenAmount = long.qty / (2 ** (config.hedgeNumberMax - 1));
            pnl.hedgeSellInitRealtime = int256(calcQuoteTokenByBaseToken(baseTokenAmount, spotPrice)) - int256(calcQuoteTokenByBaseToken(baseTokenAmount, long.price)); 
        }
        if (hedge.number > 0) {
            (
                /**uint256 liquidity */,
                uint256 quoteTokenAmountThreshold,
                uint256 targetPrice,
                /** uint256 hedgeSellPriceThreshold */
            ) = calcHedgeSellThreshold();
            pnl.hedgeSellRealtime = int256(calcQuoteTokenByBaseToken(hedge.qty, spotPrice)) - int256(calcQuoteTokenByBaseToken(hedge.qty, targetPrice));            
            pnl.hedgeSellTarget = int256(quoteTokenAmountThreshold) - int256(calcQuoteTokenByBaseToken(hedge.qty, targetPrice));
            ( 
                uint256 baseTokenAmountThreshold,
                /** uint256 hedgeLossInQuoteToken */,
                /** uint256 hedgeLossInBaseToken */,
                /** uint256 hedgeRebuyPriceThreshold */
            ) = calcHedgeRebuyThreshold();
            pnl.hedgeRebuyRealtime = int256(calcBaseTokenByQuoteToken(hedge.liquidity, hedge.price)) - int256(calcBaseTokenByQuoteToken(hedge.liquidity, spotPrice));
            pnl.hedgeRebuyTarget = int256(baseTokenAmountThreshold) - int256(calcBaseTokenByQuoteToken(hedge.liquidity, hedge.price));
        }
    }

    /// @notice return long position
    function getLong() public view virtual override
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
    function getHedge() public view virtual override
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

    /// @notice return true if position is on drawdown
    function isDrawdown() public view override returns (bool) {
        if (long.number > 0) {
            if (long.number == long.numberMax && hedge.number == 0) {
                uint256 price = getPriceQuoteTokenPerBaseToken();
                (, uint256 hedgeSellInitPriceThresholdLow) = calcHedgeSellInitBounds();
                return price < hedgeSellInitPriceThresholdLow;
            }
        }
        return false;
    }

    /// @notice return runtime
    function getRuntime() public view override returns (
        uint256 initLiquidity,
        uint256 liquidity,
        uint256 investCoef
    ) {
        return (runtime.initLiquidity, runtime.liquidity, runtime.investCoef);
    }

    /// @notice return config of strategy
    function getConfig() public view virtual override
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
    function getFeeConfig() public view virtual override
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

    /// @notice return profits of strategy pool
    function getProfits() public view virtual override
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        )
    {
        quoteTokenYieldProfit = profits.quoteTokenYieldProfit + getPendingYield(quoteToken);
        baseTokenYieldProfit = profits.baseTokenYieldProfit + getPendingYield(baseToken);
        quoteTokenTradeProfit = profits.quoteTokenTradeProfit;
        baseTokenTradeProfit = profits.baseTokenTradeProfit;
    }

    /// @notice return total profits of strategy pool
    function getTotalProfits() public view virtual override
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        )
    {
        quoteTokenYieldProfit = totalProfits.quoteTokenYieldProfit + getPendingYield(quoteToken);
        baseTokenYieldProfit = totalProfits.baseTokenYieldProfit + getPendingYield(baseToken);
        quoteTokenTradeProfit = totalProfits.quoteTokenTradeProfit;
        baseTokenTradeProfit = totalProfits.baseTokenTradeProfit;
    }

    /// @notice returns the owner of strategy pool
    /// @dev should be reimplemented in inherrited contracts
    function owner() public view virtual override(IERC5313) returns (address){
        return msg.sender; // no owner
    }

    /// @notice execute a transaction
    function execute(address target, uint256 value, bytes calldata data) public payable virtual override returns (bool success, bytes memory result) {
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        // able to receive ETH. May be inherrited and reimplemented
    }

}