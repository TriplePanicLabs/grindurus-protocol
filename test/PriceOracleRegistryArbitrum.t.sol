// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PriceOracleRegistryArbitrum} from "src/oracle/PriceOracleRegistryArbitrum.sol";
import {PriceOracleInverse} from "src/oracle/PriceOracleInverse.sol";
import {PriceOracleSelf} from "src/oracle/PriceOracleSelf.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";

// $ forge test --match-path test/PriceOracleRegistryArbitrum.t.sol -vvv
contract PriceOracleRegistryArbitrumTest is Test {
    address oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    PriceOracleRegistryArbitrum public priceOracleRegistry;
    
    uint8 dingoDongo;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);
        priceOracleRegistry = new PriceOracleRegistryArbitrum(address(0));
    }

    function test_instantiate() public {
       
        address oracle = priceOracleRegistry.getOracle(usdt, weth);
        assert(oracle == oracleWethUsdArbitrum);

        address oracleInverseAddress = priceOracleRegistry.getOracle(weth, usdt);
        assert(oracleInverseAddress != address(0));

        AggregatorV3Interface oracleInverse = AggregatorV3Interface(oracleInverseAddress);

        (,int256 inverseAnswer,,,) = oracleInverse.latestRoundData();
        assert(inverseAnswer > 0);
        dingoDongo++;
    }

}
