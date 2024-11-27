// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {GrindURUSPoolsNFT} from "src/GrindURUSPoolsNFT.sol";
import {GrindToken} from "src/GrindToken.sol";
import {GrindURUSPoolStrategy1, IToken, IGrindURUSPoolStrategy} from "src/strategy1/GrindURUSPoolStrategy1.sol";
import {FactoryGrindURUSPoolStrategy1} from "src/strategy1/FactoryGrindURUSPoolStrategy1.sol";

// $ forge test --match-path test/GrindURUSPoolsNFT.t.sol
contract GrindURUSPoolsNFTTest is Test {
    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3ArbPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    address uniswapV3SwapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 fee = 500;

    GrindURUSPoolsNFT public poolsNFT;

    GrindToken public grindToken;

    GrindURUSPoolStrategy1 public pool;

    FactoryGrindURUSPoolStrategy1 public factory1;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        deal(wethArbitrum, address(this), 1000e18);
        deal(usdtArbitrum, address(this), 1000e6);

        poolsNFT = new GrindURUSPoolsNFT();

        grindToken = new GrindToken(address(poolsNFT));

        factory1 = new FactoryGrindURUSPoolStrategy1(address(poolsNFT));

        poolsNFT.setGrindToken(address(grindToken));
        poolsNFT.setFactoryStrategy(address(factory1));
    }

    function test_mint_and_check() public {
        uint16 strategyId = 1;
        address oracleQuoteTokenPerFeeToken = oracleWethUsdArbitrum;
        address oracleQuoteTokenPerBaseToken = oracleWethUsdArbitrum;
        address feeToken = wethArbitrum;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 1e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );

        pool = GrindURUSPoolStrategy1(payable(poolsNFT.pools(poolId)));

        address grindurusPoolsNFT = address(pool.grindurusPoolsNFT());

        assert(grindurusPoolsNFT == address(poolsNFT));

        (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 averagePriceVolatility,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) = pool.config();
        averagePriceVolatility;
        assert(longNumberMax > 0);
        assert(hedgeNumberMax > 0);
        assert(extraCoef > 0);
        assert(returnPercentLongSell > 0);
        assert(returnPercentHedgeSell > 0);
        assert(returnPercentHedgeRebuy > 0);

        IToken storedBaseToken = pool.baseToken();
        address expectedBaseToken = wethArbitrum;
        assert(address(storedBaseToken) == expectedBaseToken);
    }

    function test_mint_and_grind() public {
        uint16 strategyId = 1;
        address oracleQuoteTokenPerFeeToken = oracleWethUsdArbitrum;
        address oracleQuoteTokenPerBaseToken = oracleWethUsdArbitrum;
        address feeToken = wethArbitrum;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );

        poolsNFT.grind(poolId);

        pool = GrindURUSPoolStrategy1(payable(poolsNFT.pools(poolId)));

        (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        ) = pool.long();
        number;
        numberMax;
        priceMin;
        feeQty;
        feePrice;
        assert(liquidity > 0);
        assert(qty > 0);
        assert(price > 0);
    }

    function test_mint_and_exit() public {
        uint16 strategyId = 1;
        address oracleQuoteTokenPerFeeToken = oracleWethUsdArbitrum;
        address oracleQuoteTokenPerBaseToken = oracleWethUsdArbitrum;
        address feeToken = wethArbitrum;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );

        poolsNFT.exit(poolId);

        address ownerOfAfter = poolsNFT.ownerOf(poolId);
        assert(ownerOfAfter == address(this));
    }

    function test_mint_and_buyRoyalty() public {
        uint16 strategyId = 1;
        address oracleQuoteTokenPerFeeToken = oracleWethUsdArbitrum;
        address oracleQuoteTokenPerBaseToken = oracleWethUsdArbitrum;
        address feeToken = wethArbitrum;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );

        uint256 royaltyPriceBefore = poolsNFT.royaltyPrice(poolId);
        (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 primaryReceiverShare,
            uint256 grinderShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        ) = poolsNFT.royaltyPriceShares(poolId);
        compensationShare;
        poolOwnerShare;
        primaryReceiverShare;
        grinderShare;
        oldRoyaltyPrice;
        (uint256 royaltyPricePaid, uint256 refund) = poolsNFT.buyRoyalty{value: newRoyaltyPrice}(poolId);
        royaltyPricePaid;
        refund;

        uint256 royaltyPriceAfter = poolsNFT.royaltyPrice(poolId);
        assert(royaltyPriceAfter > royaltyPriceBefore);
    }

    receive() external payable {}
}
