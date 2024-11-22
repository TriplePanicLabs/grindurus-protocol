// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
    AAVEV3AdapterArbitrum,
    IAAVEV3AToken,
    IAAVEV3PoolArbitrum,
    IToken
} from "../../src/adapters/AAVEV3AdapterArbitrum.sol";

// $ forge test --match-path test/adapters/AAVEV3AdapterArbitrum.t.sol
contract AAVEV3AdapterArbitrumTest is Test {
    address arbitrumOracle_weth_usd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3PoolArbitrum = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aArbWeth = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
    address aArbUsdt = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620;

    IToken public baseToken;

    IToken public quoteToken;

    IAAVEV3PoolArbitrum public aaveV3Pool;

    AAVEV3AdapterArbitrum public adapter;

    function setUp() public {
        vm.createSelectFork("arbitrum");

        baseToken = IToken(wethArbitrum);
        quoteToken = IToken(usdtArbitrum);

        bytes memory lendingConstructorArgs = abi.encode(address(aaveV3PoolArbitrum));
        adapter = new AAVEV3AdapterArbitrum();
        adapter.initLending(lendingConstructorArgs);
    }

    function test_baseToken_put_and_take() public {
        deal(address(baseToken), address(adapter), 1000e18);
        // IAAVEV3AToken aToken = adapter.getAToken(baseToken);
        // console.log("aToken: ", address(aToken));

        uint256 baseTokenAmount = 2e18;
        (, uint256 putAmount) = adapter.put(baseToken, baseTokenAmount);
        assertEq(baseTokenAmount, putAmount);

        uint256 aBaseTokenBalanceBefore = adapter.getAToken(baseToken).balanceOf(address(adapter));
        vm.warp(block.timestamp + 4 hours);
        uint256 aBaseTokenBalanceAfter = adapter.getAToken(baseToken).balanceOf(address(adapter));

        // console.log("Balance before: ", aBaseTokenBalanceBefore);
        // console.log("Balance after: ", aBaseTokenBalanceAfter);
        assertGt(aBaseTokenBalanceAfter, aBaseTokenBalanceBefore);

        (, uint256 takeAmount) = adapter.take(baseToken, baseTokenAmount);
        assertEq(takeAmount, baseTokenAmount);
    }
}
