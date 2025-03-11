// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
    AAVEV3AdapterArbitrum,
    IAAVEV3AToken,
    IAAVEV3PoolArbitrum,
    IToken
} from "../../src/adapters/lendings/AAVEV3AdapterArbitrum.sol";

contract TestAAVEV3AdapterArbitrum is AAVEV3AdapterArbitrum {
    function put(
        IToken token,
        uint256 amount
    ) public override returns (uint256 putAmount) {
        putAmount = _put(token, amount);
    }

    function take(
        IToken token,
        uint256 amount
    ) public override returns (uint256 takeAmount) {
        takeAmount = _take(token, amount);
    }
}

// $ forge test --match-path test/adapters/AAVEV3AdapterArbitrum.t.sol -vvv
contract AAVEV3AdapterArbitrumTest is Test {

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address aaveV3PoolArbitrum = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    IToken public baseToken;

    IToken public quoteToken;

    IAAVEV3PoolArbitrum public aaveV3Pool;

    TestAAVEV3AdapterArbitrum public adapter;

    function setUp() public {
        vm.createSelectFork("arbitrum");

        baseToken = IToken(wethArbitrum);
        quoteToken = IToken(usdtArbitrum);

        adapter = new TestAAVEV3AdapterArbitrum();
        bytes memory lendingConstructorArgs = abi.encode(address(aaveV3PoolArbitrum));
        adapter.initLending(lendingConstructorArgs);
    }

    function test_baseToken_put_and_take() public {
        deal(address(baseToken), address(adapter), 1000e18);
        // IAAVEV3AToken aToken = adapter.getAToken(baseToken);
        // console.log("aToken: ", address(aToken));

        uint256 baseTokenAmount = 2e18;
        (uint256 putAmount) = adapter.put(baseToken, baseTokenAmount);
        assertEq(baseTokenAmount, putAmount);

        uint256 aBaseTokenBalanceBefore = adapter.getAToken(baseToken).balanceOf(address(adapter));
        vm.warp(block.timestamp + 4 hours);
        uint256 aBaseTokenBalanceAfter = adapter.getAToken(baseToken).balanceOf(address(adapter));

        // console.log("Balance before: ", aBaseTokenBalanceBefore);
        // console.log("Balance after: ", aBaseTokenBalanceAfter);
        assertGt(aBaseTokenBalanceAfter, aBaseTokenBalanceBefore);

        (uint256 takeAmount) = adapter.take(baseToken, baseTokenAmount);
        assertEq(takeAmount, baseTokenAmount);
    }

    function test_unlistedToken_put_and_take() public {
        IToken unlistedToken = IToken(0x306fD3e7b169Aa4ee19412323e1a5995B8c1a1f4); // Black Agnus
        uint256 unlistedTokenAmount = 2e18;
        deal(address(unlistedToken), address(adapter), unlistedTokenAmount);

        (uint256 putAmount) = adapter.put(unlistedToken, unlistedTokenAmount);
        uint256 balance = IToken(unlistedToken).balanceOf(address(adapter));
        assertEq(balance, putAmount);

        (uint256 takeAmount) = adapter.take(unlistedToken, unlistedTokenAmount);
        balance = IToken(unlistedToken).balanceOf(address(adapter));
        assertEq(takeAmount, balance);
    }
}
