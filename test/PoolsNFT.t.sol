// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";

// $ forge test --match-path test/PoolsNFT.t.sol
contract PoolsNFTTest is Test {
    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3ArbPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    address uniswapV3SwapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 fee = 500;

    PoolsNFT public poolsNFT;

    GRETH public grindToken;

    Strategy1Arbitrum public pool;

    RegistryArbitrum public oracleRegistry;

    Strategy1FactoryArbitrum public factory1;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        deal(wethArbitrum, address(this), 1000e18);
        deal(usdtArbitrum, address(this), 1000e6);

        poolsNFT = new PoolsNFT();

        grindToken = new GRETH(address(poolsNFT));

        oracleRegistry = new RegistryArbitrum(address(poolsNFT));

        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(oracleRegistry));

        poolsNFT.setGRETH(address(grindToken));
        poolsNFT.setStrategyFactory(address(factory1));
    }

    function test_mint_and_check() public {
        uint16 strategyId = 1;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 1e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            quoteToken,
            baseToken,
            quoteTokenAmount
        );

        pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));

        address grindurusPoolsNFT = address(pool.poolsNFT());

        assert(grindurusPoolsNFT == address(poolsNFT));

        (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 priceVolatility,
            uint256 initHedgeSellPercent,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) = pool.config();
        priceVolatility; initHedgeSellPercent;
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
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            quoteToken,
            baseToken,
            quoteTokenAmount
        );

        poolsNFT.grind(poolId);

        pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));

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
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            quoteToken,
            baseToken,
            quoteTokenAmount
        );

        poolsNFT.exit(poolId);

        address ownerOfAfter = poolsNFT.ownerOf(poolId);
        address owner = poolsNFT.owner();
        assert(ownerOfAfter == owner);

    }

    function test_mint_and_buyRoyalty() public {
        uint16 strategyId = 1;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            quoteToken,
            baseToken,
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
        ) = poolsNFT.calcRoyaltyPriceShares(poolId);
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
