// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { GRETH } from "src/GRETH.sol";
import { Strategy1Arbitrum, IToken, IStrategy } from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import { Strategy1FactoryArbitrum } from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import { RegistryArbitrum } from "src/registries/RegistryArbitrum.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRAI } from "src/GRAI.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { IntentsNFT } from "src/IntentsNFT.sol";
import { TransparentUpgradeableProxy } from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// $ forge test --match-path test/PoolsNFT.t.sol -vvv
contract PoolsNFTTest is Test {
    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3ArbPool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    address uniswapV3SwapRouter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    uint24 fee = 500;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;

    GRETH public greth;

    IntentsNFT public intentsNFT;

    GRAI public grAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

    GrinderAI public grinderAI;

    Strategy1Arbitrum public pool;

    RegistryArbitrum public registry;

    Strategy1Arbitrum public strategy1;

    Strategy1FactoryArbitrum public factory1;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        deal(wethArbitrum, address(this), 1000e18);
        deal(usdtArbitrum, address(this), 1000e6);

        poolsNFT = new PoolsNFT();

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        greth = new GRETH(address(poolsNFT), wethArbitrum);

        grinderAI = new GrinderAI();
        proxyGrinderAI = new TransparentUpgradeableProxy(address(grinderAI), address(this), "");
        
        grAI = new GRAI(lzEndpointArbitrum, address(proxyGrinderAI));
        intentsNFT = new IntentsNFT(address(poolsNFT), address(grAI));

        grinderAI = GrinderAI(payable(proxyGrinderAI));
        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI), wethArbitrum);
        
        poolsNFT.init(address(poolsNFTLens), address(greth), address(grinderAI));

        registry = new RegistryArbitrum(address(poolsNFT));

        strategy1 = new Strategy1Arbitrum();

        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry));
        factory1.setStrategyImplementation(address(strategy1));

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
            baseToken,
            quoteToken,
            quoteTokenAmount
        );

        pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));

        address grindurusPoolsNFT = address(pool.poolsNFT());

        assert(grindurusPoolsNFT == address(poolsNFT));

        (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 priceVolatility,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) = pool.config();
        priceVolatility;
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
            baseToken,
            quoteToken,
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

    function test_mint_grind_withdraw2() public {
        uint16 strategyId = 1;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );
        pool = Strategy1Arbitrum(payable(poolsNFT.pools(poolId)));
    
        pool.setLongNumberMax(1);

        poolsNFT.grind(poolId);
        address to = address(this);        
        (, , , , uint256 qty, , ,) = pool.long();
        uint256 baseTokenAmount = qty / 2;
        uint256 withdrawn = poolsNFT.withdraw2(poolId, to, baseTokenAmount);
        assert (withdrawn == baseTokenAmount);
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
            baseToken,
            quoteToken,
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
        deal(quoteToken, address(this), 1000e6);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );
        uint256 royaltyPriceBefore = poolsNFT.royaltyPrice(poolId);
        (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 reserveShare,
            uint256 ownerShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice // compensationShare + poolOwnerShare + reserveShare + ownerShare
        ) = poolsNFT.calcRoyaltyPriceShares(poolId);
        IToken(quoteToken).approve(address(poolsNFT), newRoyaltyPrice);
        compensationShare;
        poolOwnerShare;
        reserveShare;
        ownerShare;
        oldRoyaltyPrice;
        uint256 royaltyPricePaid = poolsNFT.buyRoyalty(poolId);
        royaltyPricePaid;

        uint256 royaltyPriceAfter = poolsNFT.royaltyPrice(poolId);
        assert(royaltyPriceAfter > royaltyPriceBefore);
    }

    function test_transfer() public {
        uint16 strategyId = 1;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 270e6;
        deal(quoteToken, address(this), quoteTokenAmount);
        IToken(quoteToken).approve(address(poolsNFT), quoteTokenAmount);
        uint256 poolId = poolsNFT.mint(
            strategyId,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );
        address receiver = address(777);
        poolsNFT.transfer(receiver, poolId);
        address owner = poolsNFT.ownerOf(poolId);
        assert(owner == receiver);
    }

    function test_transferOwnership() public {
        address payable newOwner = payable(address(0x777));
        poolsNFT.transferOwnership(newOwner);
        address owner = poolsNFT.owner();
        address pendingOwner = poolsNFT.pendingOwner();
        assert(owner == address(this));
        assert(pendingOwner == newOwner);
        
        vm.startBroadcast(newOwner);
        poolsNFT.transferOwnership(newOwner);
        owner = poolsNFT.owner();
        assert(owner == newOwner); 
        vm.stopBroadcast();
    }

    receive() external payable {}
}
