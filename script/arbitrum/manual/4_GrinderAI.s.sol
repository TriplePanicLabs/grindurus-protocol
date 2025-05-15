// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {GRAI} from "src/GRAI.sol";
import {GrinderAI} from "src/GrinderAI.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/4_GrinderAI.s.sol:GrinderAIScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/4_GrinderAI.s.sol:GrinderAIScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract GrinderAIScript is Script {

    GrinderAI public grinderAI;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grinderAI = new GrinderAI();
        
        vm.stopBroadcast();
    }
}