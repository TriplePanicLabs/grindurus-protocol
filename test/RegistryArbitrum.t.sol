// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Test, console} from "forge-std/Test.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { RegistryArbitrum } from "src/registries/RegistryArbitrum.sol";
import { PriceOracleInverse } from "src/oracles/PriceOracleInverse.sol";
import { PriceOracleSelf } from "src/oracles/PriceOracleSelf.sol";
import { IOracle } from "src/interfaces/IOracle.sol";

// $ forge test --match-path test/RegistryArbitrum.t.sol -vvv
contract RegistryArbitrumTest is Test {
    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address oraleWbtcUsdArbitrum = 0x6ce185860a4963106506C203335A2910413708e9;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address wbtcArbitrum = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    RegistryArbitrum public registry;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        registry = new RegistryArbitrum(address(0));
    }

    function test_instantiate() public {
       
        address oracle = registry.getOracle(usdtArbitrum, wethArbitrum);
        assert(oracle == oracleWethUsdArbitrum);

        address oracleInverseAddress = registry.getOracle(wethArbitrum, usdtArbitrum);
        assert(oracleInverseAddress != address(0));

        IOracle oracleInverse = IOracle(oracleInverseAddress);

        (,int256 inverseAnswer,,,) = oracleInverse.latestRoundData();
        assert(inverseAnswer > 0);

        uint256 usdtArbitrumIndex = registry.quoteTokenIndex(usdtArbitrum);
        assert(usdtArbitrumIndex == 0);
        uint256 usdcArbitrumIndex = registry.quoteTokenIndex(usdcArbitrum);
        assert(usdcArbitrumIndex == 1);
        uint256 wethArbitrumIndex = registry.quoteTokenIndex(wethArbitrum);
        assert(wethArbitrumIndex == 2);

        wethArbitrumIndex = registry.baseTokenIndex(wethArbitrum);
        assert(wethArbitrumIndex == 0);
        usdtArbitrumIndex = registry.baseTokenIndex(usdtArbitrum);
        assert(usdtArbitrumIndex == 1);
        usdcArbitrumIndex = registry.baseTokenIndex(usdcArbitrum);
        assert(usdcArbitrumIndex == 2);
        
    }

    function test_setOracle() public {

        address[] memory baseTokensBefore = registry.getBaseTokens();

        registry.setOracle(usdtArbitrum, wbtcArbitrum, oraleWbtcUsdArbitrum);

        address[] memory baseTokensAfter = registry.getBaseTokens();
        assert(baseTokensBefore.length + 1 == baseTokensAfter.length);

        bool _hasOracle = registry.hasOracle(usdtArbitrum, wbtcArbitrum);
        assert(_hasOracle);

    }

    function test_unsetOracle() public {

        uint256 usdcCoherenceBefore = registry.quoteTokenCoherence(usdcArbitrum);
        assert(usdcCoherenceBefore == 1);
        address[] memory quoteTokensBefore = registry.getQuoteTokens();

        registry.unsetOracle(usdcArbitrum, wethArbitrum, oracleWethUsdArbitrum);

        uint256 usdcCoherenceAfter = registry.quoteTokenCoherence(usdcArbitrum);
        assert(usdcCoherenceAfter == 0);
        address[] memory quoteTokensAfter = registry.getQuoteTokens();
        assert(quoteTokensBefore.length == quoteTokensAfter.length + 1);

    }

    function test_setAndUnsetOracle() public {

        registry.setOracle(usdtArbitrum, wbtcArbitrum, oraleWbtcUsdArbitrum);

        uint256 usdtCoherenceBefore = registry.quoteTokenCoherence(usdtArbitrum);
        assert(usdtCoherenceBefore == 2);
        address[] memory quoteTokensBefore = registry.getQuoteTokens();

        registry.unsetOracle(usdtArbitrum, wbtcArbitrum, oraleWbtcUsdArbitrum);

        uint256 usdtCoherenceAfter = registry.quoteTokenCoherence(usdtArbitrum);
        assert(usdtCoherenceAfter == 1);
        address[] memory quoteTokensAfter = registry.getQuoteTokens();
        assert(quoteTokensBefore.length == quoteTokensAfter.length);
    }

}
