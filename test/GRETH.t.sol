// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { GRETH } from "src/GRETH.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GrinderAI } from "src/GrinderAI.sol";


// $ forge test --match-path test/GRETH.t.sol -vvv
contract GRETHTest is Test {
    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    address usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;
    
    GRETH public greth;

    GrinderAI public grinderAI;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);

        vm.startPrank(address(0x123));
      
        poolsNFT = new PoolsNFT();

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        greth = new GRETH(address(poolsNFT), wethArbitrum);
        
        grinderAI = new GrinderAI(address(poolsNFT));

        poolsNFT.init(address(poolsNFTLens), address(greth), address(grinderAI));

        vm.stopPrank();
    }

    function testMintToActors() public {
        address[] memory actors = new address[](2);
        actors[0] = address(0xabc);
        actors[1] = address(0xdef);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 200e18;

        vm.startPrank(address(poolsNFT));
        uint256 totalShares = greth.multimint(actors, amounts);
        vm.stopPrank();

        assertEq(totalShares, 300e18);
        assertEq(greth.balanceOf(address(0xabc)), 100e18);
        assertEq(greth.balanceOf(address(0xdef)), 200e18);
        assertEq(greth.totalSupply(), 300e18);
    }

    function testBurn() public {
        deal(wethArbitrum, address(greth), 945e18);
        address[] memory actors = new address[](1);
        actors[0] = address(this);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;

        vm.startPrank(address(poolsNFT));
        greth.multimint(actors, amounts);
        vm.stopPrank();

        uint256 burnAmount = 50e18;
        greth.burn(burnAmount, wethArbitrum);

        assertEq(greth.balanceOf(address(this)), 50e18);
    }

    function testBatchBurn() public {
        deal(wethArbitrum, address(greth), 1000e18);
        
        address[] memory actors = new address[](1);
        actors[0] = address(this);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200e18;

        vm.startPrank(address(poolsNFT));
        greth.multimint(actors, amounts);
        vm.stopPrank();

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 100e18;

        address[] memory tokens = new address[](1);
        tokens[0] = wethArbitrum;

        uint256[] memory tokenAmount = greth.batchBurn(burnAmounts, tokens);

        tokenAmount;
        assertEq(greth.balanceOf(address(this)), 100e18);
    }

    function testReceiveETH() public {
        uint256 initialWethBalance = IWETH9(wethArbitrum).balanceOf(address(greth));
        uint256 depositAmount = 1 ether;

        (bool success,) = address(greth).call{value: depositAmount}("");
        assertTrue(success, "ETH transfer failed");

        uint256 finalWethBalance = IWETH9(wethArbitrum).balanceOf(address(greth));
        assertEq(finalWethBalance, initialWethBalance + depositAmount, "WETH balance mismatch");
    }
}