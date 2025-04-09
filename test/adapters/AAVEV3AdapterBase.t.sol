// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {
    AAVEV3AdapterBase,
    IAAVEV3AToken,
    IAAVEV3PoolBase,
    IToken
} from "../../src/adapters/lendings/AAVEV3AdapterBase.sol";

contract TestAAVEV3AdapterBase is AAVEV3AdapterBase {
    function put(
        IToken token,
        uint256 amount
    ) public returns (uint256 putAmount) {
        putAmount = _put(token, amount);
    }

    function take(
        IToken token,
        uint256 amount
    ) public returns (uint256 takeAmount) {
        takeAmount = _take(token, amount);
    }
}

// $ forge test --match-path test/adapters/AAVEV3AdapterBase.t.sol -vvv
contract AAVEV3AdapterBaseTest is Test {

    address wethBase = 0x4200000000000000000000000000000000000006;
    address usdcBase = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    address aaveV3PoolBase = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    IToken public baseToken;

    IToken public quoteToken;

    IAAVEV3PoolBase public aaveV3Pool;

    TestAAVEV3AdapterBase public adapter;

    function setUp() public {
        vm.createSelectFork("base");

        baseToken = IToken(wethBase);
        quoteToken = IToken(usdcBase);

        adapter = new TestAAVEV3AdapterBase();
        bytes memory lendingConstructorArgs = abi.encode(address(aaveV3PoolBase));
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
        IToken unlistedToken = IToken(0x0578d8A44db98B23BF096A382e016e29a5Ce0ffe); // HIGHER
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
