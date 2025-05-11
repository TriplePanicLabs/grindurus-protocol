// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { IToken } from "src/interfaces/IToken.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRETH } from "src/GRETH.sol";
import { GRAI } from "src/GRAI.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { TransparentUpgradeableProxy } from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Agent } from "src/Agent.sol";
import { AgentsNFT } from "src/AgentsNFT.sol";
import { RegistryArbitrum } from "src/registries/RegistryArbitrum.sol";
import { Strategy0Arbitrum } from "src/strategies/arbitrum/strategy0/Strategy0Arbitrum.sol";
import { Strategy0FactoryArbitrum} from "src/strategies/arbitrum/strategy0/Strategy0FactoryArbitrum.sol";
import { Strategy1Arbitrum } from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import { Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";

// $ forge test --match-path test/GrinderAI.t.sol -vvv
contract GrinderAITest is Test {

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address oraleWbtcUsdArbitrum = 0x6ce185860a4963106506C203335A2910413708e9;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address wbtcArbitrum = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    address owner = 0xC185CDED750dc34D1b289355Fe62d10e86BEDDee;
    address user = 0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3;
    address receiver = 0xBD4B3DD090C819FE3779946AEc199dd1b9E65CA8;

    PoolsNFT public poolsNFT;
    PoolsNFTLens public poolsNFTLens;

    GRETH public grETH;

    GRAI public grAI;
    GrinderAI public grinderAI;
    TransparentUpgradeableProxy public proxyGrinderAI;

    RegistryArbitrum public registry;

    Strategy0Arbitrum public strategy0;
    Strategy0FactoryArbitrum public factory0;

    Strategy1Arbitrum public strategy1;
    Strategy1FactoryArbitrum public factory1;
    
    Agent public agent;
    AgentsNFT public agentsNFT;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.startBroadcast(owner);
        vm.txGasPrice(0.05 gwei);

        poolsNFT = new PoolsNFT();
        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));

        grETH = new GRETH(address(poolsNFT), wethArbitrum);
        grinderAI = new GrinderAI();
        proxyGrinderAI = new TransparentUpgradeableProxy(address(grinderAI), address(this), "");

        grAI = new GRAI(lzEndpointArbitrum, address(proxyGrinderAI));
        
        grinderAI = GrinderAI(payable(proxyGrinderAI));
        grinderAI.init(address(poolsNFT), address(grAI), wethArbitrum);

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(proxyGrinderAI));

        registry = new RegistryArbitrum(address(poolsNFT));

        strategy0 = new Strategy0Arbitrum();
        factory0 = new Strategy0FactoryArbitrum(address(poolsNFT), address(registry));
        factory0.setStrategyImplementation(address(strategy0));

        strategy1 = new Strategy1Arbitrum();
        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry));
        factory1.setStrategyImplementation(address(strategy1));

        poolsNFT.setStrategyFactory(address(factory0));
        poolsNFT.setStrategyFactory(address(factory1));

        agent = new Agent();
        agentsNFT = new AgentsNFT(address(poolsNFT));
        agentsNFT.setAgentImplementation(address(agent));
    
        vm.stopBroadcast();
    }

    function test_mint() public {
        vm.startBroadcast(user);
        deal(user, 1e18);
        uint256 graiAmount = 600 * 1e18; // 600 GRAI
        uint256 paymentAmount = grinderAI.calcPayment(address(0), graiAmount);
        //console.log("paymentAmount: ", paymentAmount);
        
        uint256 grinderBalanceBefore = grinderAI.grinder().balance;
        grinderAI.mint{value: paymentAmount}(address(0), graiAmount);
        uint256 grinderBalanceAfter = grinderAI.grinder().balance;
        assert(grinderBalanceAfter > grinderBalanceBefore);

        vm.stopBroadcast();
    }

    function test_doubleMint() public {
        vm.startBroadcast(user);
        deal(user, 1e18);
        uint256 graiAmount = 600 * 1e18; // 600 GRAI
        uint256 paymentAmount = grinderAI.calcPayment(address(0), graiAmount);
        //console.log("paymentAmount: ", paymentAmount);
        
        uint256 grinderBalanceBefore = grinderAI.grinder().balance;
        grinderAI.mint{value: paymentAmount}(address(0), graiAmount);
        grinderAI.mint{value: paymentAmount}(address(0), graiAmount);
        uint256 grinderBalanceAfter = grinderAI.grinder().balance;
        assert(grinderBalanceAfter > grinderBalanceBefore);

        vm.stopBroadcast();
    }

    function test_mint_usdt() public {
        vm.startBroadcast(owner);
        grinderAI.setRatePerGRAI(usdtArbitrum, 1e6); // 1 USDT
        vm.stopBroadcast();
        vm.startBroadcast(user);
        deal(usdtArbitrum, user, 1000e6);
        uint256 graiAmount = 600 * 1e18; // 600 GRAI
        uint256 paymentAmount = grinderAI.calcPayment(usdtArbitrum, graiAmount);

        IToken usdt = IToken(usdtArbitrum);
        usdt.approve(address(grinderAI), paymentAmount);
        // console.log("   paymentAmount: ", paymentAmount);

        uint256 grinderBalanceBefore = usdt.balanceOf(address(grinderAI));
        grinderAI.mint(usdtArbitrum, graiAmount);
        uint256 grinderBalanceAfter = usdt.balanceOf(address(grinderAI));
        assert(grinderBalanceAfter > grinderBalanceBefore);

        vm.stopBroadcast();
    }

    function test_withdraw() public {
        vm.startBroadcast(owner);
        deal(wethArbitrum, address(grinderAI), 1e18);
        uint256 amount = grinderAI.withdraw(wethArbitrum, 1e18);
        assert(amount == 1e18);
        vm.stopBroadcast();
    }

    function test_grind() public {
        address grinder = grinderAI.grinder();
        vm.startBroadcast(user);
        deal(user, 1e18);
        deal(usdtArbitrum, user, 1000e6);

        uint256 graiAmount = 100 * 1e18; // 600 GRAI
        uint256 payment = grinderAI.calcPayment(address(0), graiAmount);
        grinderAI.mint{value: payment}(address(0), graiAmount);

        uint16 strategyId = 0;
        address baseToken = wethArbitrum;
        address quoteToken = usdtArbitrum;
        uint256 quoteTokenAmount = 300e6; // 1 USDT
        uint256 liquidityFragment = 100e6; // 1 USDT
        uint16 positionsMax = 2;
        uint16 subnodesMax = 1;
        IToken usdt = IToken(quoteToken);
        usdt.approve(address(agentsNFT), quoteTokenAmount);
        uint256 agentId = agentsNFT.mint(strategyId, baseToken, quoteToken, quoteTokenAmount, liquidityFragment, positionsMax, subnodesMax);        
        vm.stopBroadcast();

        vm.startBroadcast(grinder);
        uint256[] memory poolIds = agentsNFT.getPoolIds(agentId);
        bool success = grinderAI.grind(poolIds[0]);
        assert(success == true);

        vm.stopBroadcast();

    }

}
