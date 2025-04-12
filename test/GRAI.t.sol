// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {GRAI} from "src/GRAI.sol";

// $ forge test --match-path test/GRAI.t.sol -vvv
contract GRAITest is Test {

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 baseEndpointId = 30184;

    GRAI public grAI;

    function setUp() public {
        vm.createSelectFork("arbitrum");
        vm.txGasPrice(0.05 gwei);

        grAI = new GRAI(lzEndpointArbitrum, address(this));

        bytes32 peer = grAI.addressToBytes32(address(1337));
        grAI.setPeer(baseEndpointId, peer);

        grAI.mint(address(this), 100e18);
        console.log("grAI balance:", grAI.balanceOf(address(this)));
    }

    function test_bridgeTo() public {
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
        grAI.setNativeBridgeFee(1_00);// 1%
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

    receive() external payable {
    
    }

}
