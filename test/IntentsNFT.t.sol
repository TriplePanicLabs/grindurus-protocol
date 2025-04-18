// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {IIntentsNFT} from "src/interfaces/IIntentsNFT.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {IToken} from "src/interfaces/IToken.sol";

// $ forge test --match-path test/IntentsNFT.t.sol -vvv
contract IntentsNFTTest is Test {
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

    IntentsNFT public intentsNFT;


    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.startBroadcast(owner);
        vm.txGasPrice(0.05 gwei);

        poolsNFT = new PoolsNFT();
        intentsNFT = new IntentsNFT(address(poolsNFT));
        intentsNFT.setRatePerGrind(address(0), 1e12); // 0.000001 ETH
        intentsNFT.setRatePerGrind(usdtArbitrum, 1e6); // 1 USDT
        vm.stopBroadcast();
    }


    function test_mint() public {
        vm.startBroadcast(user);
        deal(user, 1e18);
        uint256 grinds = 600;
        uint256 paymentAmount = intentsNFT.calcPayment(address(0), grinds);
        //console.log("paymentAmount: ", paymentAmount);
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 intentId = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        uint256 ownerBalanceAfter = owner.balance;
        assert(intentId == 1);
        assert(ownerBalanceAfter > ownerBalanceBefore);

        vm.stopBroadcast();
    }

    function test_doubleMint() public {
        vm.startBroadcast(user);
        deal(user, 1e18);
        uint256 grinds = 600;
        uint256 paymentAmount = intentsNFT.calcPayment(address(0), grinds);
        //console.log("paymentAmount: ", paymentAmount);
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 intentId = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        uint256 intentId2 = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        uint256 ownerBalanceAfter = owner.balance;
        assert(intentId == 1);
        assert(intentId == intentId2);
        assert(ownerBalanceAfter > ownerBalanceBefore);

        vm.stopBroadcast();
    }

    function test_mint_usdt() public {
        vm.startBroadcast(user);
        deal(usdtArbitrum, user, 1000e6);
        uint256 grinds = 600;
        uint256 paymentAmount = intentsNFT.calcPayment(usdtArbitrum, grinds);

        IToken usdt = IToken(usdtArbitrum);
        usdt.approve(address(intentsNFT), paymentAmount);

        uint256 ownerBalanceBefore = usdt.balanceOf(owner);
        uint256 intentId = intentsNFT.mint(usdtArbitrum, grinds);
        uint256 ownerBalanceAfter = usdt.balanceOf(owner);
        assert(intentId == 1);
        assert(ownerBalanceAfter > ownerBalanceBefore);

        vm.stopBroadcast();
    }

}
