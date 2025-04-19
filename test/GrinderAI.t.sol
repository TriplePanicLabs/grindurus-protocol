// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IToken} from "src/interfaces/IToken.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {GRETH} from "src/GRETH.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {GRAI} from "src/GRAI.sol";
import {GrinderAI} from "src/GrinderAI.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

    IntentsNFT public intentsNFT;

    GRAI public grAI;

    GrinderAI public grinderAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

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

        intentsNFT = new IntentsNFT(address(poolsNFT), address(grAI));
        
        grinderAI = GrinderAI(payable(proxyGrinderAI));
        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(proxyGrinderAI));

        vm.stopBroadcast();
    }


    function test_() public {
        // vm.startBroadcast(user);
        // deal(user, 1e18);
        // uint256 period = 60 days;
        // uint256 paymentAmount = intentNFT.calcPayment(address(0), period);
        // //console.log("paymentAmount: ", paymentAmount);
        
        // uint256 ownerBalanceBefore = owner.balance;
        // uint256 intentId = intentNFT.mint{value: paymentAmount}(address(0), period);
        // uint256 ownerBalanceAfter = owner.balance;

        // assert(ownerBalanceAfter > ownerBalanceBefore);

        // vm.stopBroadcast();
    }

}
