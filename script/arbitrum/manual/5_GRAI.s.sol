// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {GRAI} from "src/GRAI.sol";
import {GrinderAI} from "src/GrinderAI.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/5_GRAI.s.sol:GRAI

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/5_GRAI.s.sol:GRAI --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract GRAIScript is Script {
    address public lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;
    
    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be replaced

    GrinderAI public grinderAI = GrinderAI(payable(address(0))); // address can be replaced

    GRAI public grAI;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grAI = new GRAI(lzEndpointArbitrum, address(grinderAI));

        vm.stopBroadcast();
    }
}
