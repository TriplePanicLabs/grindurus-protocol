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

// $ forge test --match-path test/GRAI.t.sol -vvv
contract GRAITest is Test {
    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    
    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 baseEndpointId = 30184;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;

    GRETH public grETH;

    IntentsNFT public intentsNFT;

    GRAI public grAI;

    GrinderAI public grinderAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

    function setUp() public {
        vm.createSelectFork("arbitrum");
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

        bytes32 peer = grAI.addressToBytes32(address(1337));
        grinderAI.setPeer(baseEndpointId, peer);

    }

    function test_bridgeTo() public {
        address paymentToken = address(0); // ETH
        uint256 grinds = 10;
        uint256 paymentAmount = intentsNFT.calcPayment(paymentToken, grinds);
        (uint256 intentId, ) = intentsNFT.mint{value: paymentAmount}(paymentToken, grinds);
        
        uint32 dstChainId = baseEndpointId;
        bytes32 toAddress = grAI.addressToBytes32(address(this));
        uint256 amount = 2e18;
        ( 
            uint256 nativeFee, 
            uint256 nativeBridgeFee, 
            uint256 totalNativeFee
        ) = grAI.getTotalFeesForBridgeTo(dstChainId, toAddress, amount);
        uint256 grAIbefore = grAI.balanceOf(address(this));
        grAI.bridgeTo{value: totalNativeFee}(dstChainId, toAddress, amount);
        uint256 grAIafter = grAI.balanceOf(address(this));
        assert(grAIafter == grAIbefore - amount);
    }

    function test_bridgeTo_withBridgeFee() public {
        address paymentToken = address(0); // ETH
        uint256 grinds = 10;
        uint256 paymentAmount = intentsNFT.calcPayment(paymentToken, grinds);
        (uint256 intentId, ) = intentsNFT.mint{value: paymentAmount}(paymentToken, grinds);

        grinderAI.setNativeBridgeFee(1_00);// 1%
        uint32 dstChainId = baseEndpointId;
        bytes32 toAddress = grAI.addressToBytes32(address(this));
        uint256 amount = 2e18;
        ( 
            uint256 nativeFee, 
            uint256 nativeBridgeFee, 
            uint256 totalNativeFee
        ) = grAI.getTotalFeesForBridgeTo(dstChainId, toAddress, amount);
        grAI.bridgeTo{value: totalNativeFee}(dstChainId, toAddress, amount);
    }

    function test_execute() public {
        address target = address(0x333);
        uint256 value = 1e18;
        bytes memory data = "";
        uint256 balanceBefore = target.balance;
        grinderAI.executeGRAI{value: value}(target, value, data);
        uint256 balanceAfter = target.balance;
        assert(balanceAfter == balanceBefore + value);
    }

    receive() external payable {
    
    }

}
