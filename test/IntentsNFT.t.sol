// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRETH } from "src/GRETH.sol";
import { IntentsNFT } from "src/IntentsNFT.sol";
import { GRAI } from "src/GRAI.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { TransparentUpgradeableProxy } from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IToken} from "src/interfaces/IToken.sol";

// $ forge test --match-path test/IntentsNFT.t.sol -vvv
contract IntentsNFTTest is Test {
    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address owner = 0xC185CDED750dc34D1b289355Fe62d10e86BEDDee;
    address user = 0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3;

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
        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI), wethArbitrum);

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(proxyGrinderAI));

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
        (uint256 intentId, ) = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        uint256 ownerBalanceAfter = owner.balance;
        assert(intentId == 0);
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
        (uint256 intentId,) = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        (uint256 intentId2,) = intentsNFT.mint{value: paymentAmount}(address(0), grinds);
        uint256 ownerBalanceAfter = owner.balance;
        assert(intentId == 0);
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
        (uint256 intentId,) = intentsNFT.mint(usdtArbitrum, grinds);
        uint256 ownerBalanceAfter = usdt.balanceOf(owner);
        assert(intentId == 0);
        assert(ownerBalanceAfter > ownerBalanceBefore);

        vm.stopBroadcast();
    }

    function test_mint_grAI() public {
        vm.startBroadcast(user);
        deal(address(grAI), user, 10 * 1e18);
        uint256 grinds = 10;
        uint256 paymentAmount = intentsNFT.calcPayment(address(grAI), grinds);
        // console.log("paymentAmount: ", paymentAmount);
        
        // grAI.approve(address(intentsNFT), paymentAmount);
        
        uint256 ownerBalanceBefore = grAI.balanceOf(owner);
        (uint256 intentId,) = intentsNFT.mint(address(grAI), grinds);
        uint256 ownerBalanceAfter = grAI.balanceOf(owner);
        assert(intentId == 0);
        assert(ownerBalanceAfter > ownerBalanceBefore);

        vm.stopBroadcast();
    }

}
