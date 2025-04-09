// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {MockToken} from "test/mock/MockToken.sol";
import {MockSwapRouterArbitrum} from "test/mock/MockSwapRouterArbitrum.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {GRAI} from "src/GRAI.sol";
import {GrinderAI} from "src/GrinderAI.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// $ forge test --match-path test/URUSStrategy1Arbitrum.t.sol -vvv
contract URUSStrategy1ArbitrumTest is Test {

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3ArbPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    uint24 fee = 500;

    address owner = 0xC185CDED750dc34D1b289355Fe62d10e86BEDDee;

    uint256 poolId0;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;
    
    GRETH public grETH;

    IntentsNFT public intentsNFT;

    GRAI public grAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

    GrinderAI public grinderAI;

    Strategy1Arbitrum public pool0;

    RegistryArbitrum public oracleRegistry;

    Strategy1Arbitrum public strategy1;

    Strategy1FactoryArbitrum public factory1;

    MockSwapRouterArbitrum public mockSwapRouter;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        vm.startBroadcast(owner);

        deal(wethArbitrum, owner, 1000e18);
        deal(usdtArbitrum, owner, 20000e6);

        poolsNFT = new PoolsNFT();

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        grETH = new GRETH(address(poolsNFT), wethArbitrum);

        intentsNFT = new IntentsNFT(address(poolsNFT));

        grinderAI = new GrinderAI();

        proxyGrinderAI = new TransparentUpgradeableProxy(address(grinderAI), owner, "");
        
        grAI = new GRAI(lzEndpointArbitrum, address(proxyGrinderAI));

        grinderAI = GrinderAI(payable(proxyGrinderAI));
        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI));

        oracleRegistry = new RegistryArbitrum(address(poolsNFT));
        strategy1 = new Strategy1Arbitrum();
        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(oracleRegistry));
        factory1.setStrategyImplementation(address(strategy1));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(grinderAI));
        poolsNFT.setStrategyFactory(address(factory1));

        mockSwapRouter = new MockSwapRouterArbitrum();
        mockSwapRouter.setRate(3000 * 10 ** 8);
        deal(wethArbitrum, address(mockSwapRouter), 1_000_000e18);
        deal(usdtArbitrum, address(mockSwapRouter), 1_000_000e6);

        uint256 amount =  1000 * 10**6;
        IToken(usdtArbitrum).approve(address(poolsNFT), amount);

        poolId0 = poolsNFT.mint(
            1,                      // strategyId
            wethArbitrum,           // baseToken
            usdtArbitrum,           // quoteToken
            amount                  // quoteTokenAmount
        );
        address pool0Address = poolsNFT.pools(poolId0);
        pool0 = Strategy1Arbitrum(payable(pool0Address));    
    }

    function test_URUS_longBuy_longSell() public {
        pool0.setSwapRouter(address(mockSwapRouter));
        pool0.setLongNumberMax(1);
        mockSwapRouter.setRate(3000 * 10 ** 8);

        (uint256 qty0, uint256 price0) = printLongPosition(poolId0);
        assert(qty0 == 0); // no long position
        assert(price0 == 0); // no long position
        poolsNFT.grind(poolId0);
        console.log("1) First purchase made.");
        (uint256 qty1, uint256 price1) = printLongPosition(poolId0);
        assert(qty1 > 0); // assert that purchase is made
        assert(price1 > 0); // assert that purchase is made
   
        mockSwapRouter.setRate(3100 * 10 ** 8);
        console.log("2) Price set to 3100");

        poolsNFT.grind(poolId0);
        console.log("3) Sell made");
        (uint256 qty3, uint256 price3) = printLongPosition(poolId0);
        assert(qty3 == 0); // close position
        assert(price3 == 0); // close position
    
        ( 
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        ) = pool0.getTotalProfits();
        console.log("quote yield profit: ", quoteTokenYieldProfit);
        console.log("base yield profit:  ", baseTokenYieldProfit);
        console.log("quote yield profit: ", quoteTokenTradeProfit);
        console.log("base yield profit:  ", baseTokenTradeProfit);
        assert(quoteTokenTradeProfit > 0);

    }

    function test_URUS_full_states() public {
        
        pool0.setSwapRouter(address(mockSwapRouter));
        pool0.setLongNumberMax(4);
        pool0.setHedgeNumberMax(4);
        pool0.setExtraCoef(2_00); // x2.00
        pool0.setPriceVolatilityPercent(1_00); // 1%
        
        (uint256 qty0, uint256 price0) = printLongPosition(poolId0);
        assert(qty0 == 0); // no long position
        assert(price0 == 0); // no long position
        poolsNFT.grind(poolId0);
        console.log("1) First purchase made.");
        (uint256 qty1, uint256 price1) = printLongPosition(poolId0);
        assert(qty1 > 0); // purchase is made
        assert(price1 > 0); // purchase is made 

        mockSwapRouter.setRate(2700 * 10 ** 8); // Decrease price by setting new rate
        console.log("2) Price decreased by 10%.");

        poolsNFT.grind(poolId0);
        console.log("3) Second purchase made.");
        (uint256 qty3, uint256 price3) = printLongPosition(poolId0);
        assert(qty3 > qty1);
        assert(price3 < price1);

        mockSwapRouter.setRate(2400 * 10 ** 8); // Decrease price further
        console.log("4) Price decreased by another 10%.");

        poolsNFT.grind(poolId0);
        console.log("5) Third purchase made.");
        (uint256 qty5, uint256 price5) = printLongPosition(poolId0);
        assert(qty5 > qty3);
        assert(price5 < price3);
        
        mockSwapRouter.setRate(2100 * 10 ** 8); // Decrease price further
        console.log("6) Price decreased by another 10%.");

        poolsNFT.grind(poolId0);
        console.log("7) Fourth purchase made.");
        (uint256 qty7, uint256 price7) = printLongPosition(poolId0);
        assert(qty7 > qty5);
        assert(price7 < price5);

        mockSwapRouter.setRate(2190 * 10 ** 8); // increase a little bit for initialize hedge sell bounds
        console.log("8) Price decreased by another 10%.");
        (uint256 thresholdHigh, uint256 thresholdLow) = pool0.calcHedgeSellInitBounds();
        
        console.log();
        console.log("HedgeSell High: ", uintToDecimal(thresholdHigh,8));
        console.log("HedgeSell Low:  ", uintToDecimal(thresholdLow,8));
        
        poolsNFT.grind(poolId0);
        console.log();
        console.log("9) Hedge sell executed.");
        (uint256 qty9, uint256 price9) = printLongPosition(poolId0);
        (uint256 hqty9, uint256 hprice9) = printHedgePosition(poolId0);
        assert(qty9 < qty7); // hedge sold
        assert(hqty9 == qty7 - qty9); // init hedge positions
        assert(hprice9 > 0); // init hedge position price 
    
        printHedgeRebuyParams(poolId0);

        mockSwapRouter.setRate(2140 * 10 ** 8); // Decrease price further
        console.log("10) Price set to 2140.");

        poolsNFT.grind(poolId0);
        console.log("11) Rebuy executed.");
        (uint256 qty11, uint256 price11) = printLongPosition(poolId0);
        (uint256 hqty11, uint256 hprice11) = printHedgePosition(poolId0);
        assert(qty11 > qty9); // rebuy should cause returning of sold qty
        assert(price11 < price9); // rebuy should cause decrease the position price
        assert(hqty11 == 0); // rebougth
        assert(hprice11 == 0); // rebought

        /// HEDGE SELLING to the end

        (thresholdHigh, thresholdLow) = pool0.calcHedgeSellInitBounds();
        
        console.log();
        console.log("HedgeSell High: ", uintToDecimal(thresholdHigh,8));
        console.log("HedgeSell Low:  ", uintToDecimal(thresholdLow,8));

        mockSwapRouter.setRate(2190 * 10 ** 8); // Decrease price further
        console.log("12) Price set to 2190");
        poolsNFT.grind(poolId0);
        console.log("13) Init hedge sell");
        (uint256 qty13, uint256 price13) = printLongPosition(poolId0);
        (uint256 hqty13, uint256 hprice13) = printHedgePosition(poolId0);
        assert(qty11 > qty13); // decrease qty in long position
        assert(price11 == price13); // price same
        assert(hqty13 > 0); // initialize hedge position
        assert(hprice13 > 0); // initialize hedge position

        mockSwapRouter.setRate(2250 * 10 ** 8);
        console.log("14) Price set to 2240");
        poolsNFT.grind(poolId0);
        console.log("15) Hedge sell");
        printLongPosition(poolId0);
        (uint256 hqty15, uint256 hprice15) = printHedgePosition(poolId0);
        assert(hqty15 > hqty13); // hedge selling increase qty
        assert(hprice15 > hprice13); // hedge selling increase price 

        poolsNFT.grind(poolId0);
        console.log();
        console.log("16) Hedge sell");
        printLongPosition(poolId0);
        (uint256 hqty16, uint256 hprice16) = printHedgePosition(poolId0);
        assert(hqty16 > hqty15); // hedge selling increase qty
        assert(hprice16 > hprice15); // hedge selling increase price 

        poolsNFT.grind(poolId0);
        console.log();
        console.log("17) Hedge sell with close the position");
        printLongPosition(poolId0);
        (uint256 hqty17, uint256 hprice17) = printHedgePosition(poolId0);
        assert(hqty17 == 0); // hedge sell close the positon 
        assert(hprice17 == 0); // hedge sell close the position
    }

    function test_rebuy() public {
        pool0.setSwapRouter(address(mockSwapRouter));
        pool0.setLongNumberMax(1);
        pool0.setHedgeNumberMax(2);
        
        mockSwapRouter.setRate(2000 * 10 ** 8);
        (uint256 qty0, uint256 price0) = printLongPosition(poolId0);
        (uint256 hqty0, uint256 hprice0) = printHedgePosition(poolId0);

        poolsNFT.grind(poolId0);
        console.log("1) Long buy");
        (uint256 qty1, uint256 price1) = printLongPosition(poolId0);
        (uint256 hqty1, uint256 hprice1) = printHedgePosition(poolId0);

        (uint256 thresholdHigh, uint256 thresholdLow) = pool0.calcHedgeSellInitBounds();
        
        console.log();
        console.log("HedgeSell High: ", uintToDecimal(thresholdHigh,8));
        console.log("HedgeSell Low:  ", uintToDecimal(thresholdLow,8));
        mockSwapRouter.setRate(1991 * 10 ** 8);
        console.log();
        console.log("2) Set price 1991");
        console.log();
        (uint256 qty2, uint256 price2) = printLongPosition(poolId0);
        (uint256 hqty2, uint256 hprice2) = printHedgePosition(poolId0);
        poolsNFT.grind(poolId0);
        console.log("3) hedge sell init");
        (uint256 qty3, uint256 price3) = printLongPosition(poolId0);
        (uint256 hqty3, uint256 hprice3) = printHedgePosition(poolId0);

        printHedgeRebuyParams(poolId0);

        mockSwapRouter.setRate(1960 * 10 ** 8);

        poolsNFT.grind(poolId0);
        console.log("4) hedge rebuy");
        (uint256 qty4, uint256 price4) = printLongPosition(poolId0);
        (uint256 hqty4, uint256 hprice4) = printHedgePosition(poolId0);

    }

    function test_rebalance() public {
        
        uint256 amount1 = 1000 * 10**6;
        IToken(usdtArbitrum).approve(address(poolsNFT), amount1);

        uint256 poolId1 = poolsNFT.mint(
            1,                      // strategyId
            wethArbitrum,           // baseToken
            usdtArbitrum,           // quoteToken
            amount1                 // quoteTokenAmount
        );
        address pool1Address = poolsNFT.pools(poolId1);
        Strategy1Arbitrum pool1 = Strategy1Arbitrum(payable(pool1Address));
        pool1.setLongNumberMax(1);
        pool1.setSwapRouter(address(mockSwapRouter));

        uint256 amount2 = 1000 * 10**6;
        IToken(usdtArbitrum).approve(address(poolsNFT), amount2);
        uint256 poolId2 = poolsNFT.mint(
            1,                      // strategyId
            wethArbitrum,           // baseToken
            usdtArbitrum,           // quoteToken
            amount2                 // quoteTokenAmount
        );
        address pool2Address = poolsNFT.pools(poolId2);
        Strategy1Arbitrum pool2 = Strategy1Arbitrum(payable(pool2Address));
        pool2.setLongNumberMax(1);
        pool2.setSwapRouter(address(mockSwapRouter));

        mockSwapRouter.setRate(3000 * 10 ** 8);
        poolsNFT.grind(poolId1);
        printLongPosition(poolId1);

        mockSwapRouter.setRate(2000 * 10 ** 8);
        poolsNFT.grind(poolId2);
        printLongPosition(poolId2);

        poolsNFT.rebalance(poolId1, poolId2, 1, 1);
        printLongPosition(poolId1);
        printLongPosition(poolId2);

    }

    function test_dip_and_undip() public {
        pool0.setSwapRouter(address(mockSwapRouter));
        
        pool0.setLongNumberMax(1);
        pool0.setHedgeNumberMax(2);
        pool0.setExtraCoef(2_00); // x2.00
        pool0.setPriceVolatilityPercent(1_00); // 1%
        
        poolsNFT.grind(poolId0);
        console.log("1) Long buy");
        printLongPosition(poolId0);
        
        (uint256 thresholdHigh, uint256 thresholdLow) = pool0.calcHedgeSellInitBounds();
    
        console.log();
        console.log("HedgeSell High: ", uintToDecimal(thresholdHigh,8));
        console.log("HedgeSell Low:  ", uintToDecimal(thresholdLow,8));
            
        uint256 amount2 = 2000 * 10**6;
        IToken(usdtArbitrum).approve(address(poolsNFT), amount2);
        mockSwapRouter.setRate(2970 * 10 ** 8);
        poolsNFT.dip(poolId0, usdtArbitrum, amount2);
        console.log("2) Dip");
        printLongPosition(poolId0);

        mockSwapRouter.setRate(3000 * 10 ** 8);
        console.log("3) Set price 3000");

        poolsNFT.grind(poolId0);
        console.log("4) Long sell");
        printLongPosition(poolId0);

        poolsNFT.withdraw(poolId0, type(uint256).max);
        console.log("5) Withdraw");
        printLongPosition(poolId0);
    }

    function printLongPosition(uint256 poolId) internal view returns (uint256 _qty, uint256 _price) {
        Strategy1Arbitrum _pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));
        (uint8 number, uint8 numberMax, uint256 priceMin, uint256 liquidity, uint256 qty, uint256 price, uint256 feeQty, uint256 feePrice) = _pool.getLong();
        numberMax; priceMin; feeQty; feePrice;
        console.log("Long Position: ", poolId);
        console.log("   num:   ", number);
        console.log("   qty:   ", uintToDecimal(qty, 18));
        console.log("   price: ", uintToDecimal(price, 8));
        console.log("   liq:   ", uintToDecimal(liquidity, 6));
        _qty = qty;
        _price = price;
    }

    function printHedgePosition(uint256 poolId) internal view returns (uint256 _qty, uint256 _price) {
        Strategy1Arbitrum _pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));
        (uint8 number, uint8 numberMax, uint256 priceMin, uint256 liquidity, uint256 qty, uint256 price, uint256 feeQty, uint256 feePrice) = _pool.getHedge();
        numberMax; priceMin; feeQty; feePrice;
        console.log("Hedge Position: ", poolId);
        console.log("   num:   ", number);
        console.log("   qty:   ", uintToDecimal(qty, 18));
        console.log("   price: ", uintToDecimal(price, 8));
        console.log("   liq:   ", uintToDecimal(liquidity, 6));
        _qty = qty;
        _price = price;
    }

    function printHedgeRebuyParams(uint256 poolId) internal view {
        Strategy1Arbitrum _pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));
        ( 
            uint256 baseTokenAmountThreshold10,
            uint256 hedgeLossInQuoteToken10,
            uint256 hedgeLossInBaseToken10,
            uint256 hedgeRebuyPriceThreshold10
        ) = _pool.calcHedgeRebuyThreshold();

        console.log("10) baseTokenAmountThreshold: ", uintToDecimal(baseTokenAmountThreshold10, 18));
        console.log("10) hedgeLossInQuoteToken:    ", uintToDecimal(hedgeLossInQuoteToken10, 6));
        console.log("10) hedgeLossInBaseToken:     ", uintToDecimal(hedgeLossInBaseToken10, 18));
        console.log("10) hedge rebuy threshold:    ", uintToDecimal(hedgeRebuyPriceThreshold10, 8));
    }

    function uintToDecimal(uint256 value, uint8 decimals) internal pure returns (string memory) {
        uint256 integerPart = value / (10 ** decimals);
        uint256 fractionalPart = value % (10 ** decimals);
        bytes memory fractionalString = new bytes(decimals);
        for (uint8 i = 0; i < decimals; i++) {
            fractionalString[i] = bytes1(uint8(48 + (fractionalPart / (10 ** (decimals - i - 1))) % 10));
        }
        return string(abi.encodePacked(uintToString(integerPart), ".", string(fractionalString)));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
