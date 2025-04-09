// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {GrinderAI} from "src/GrinderAI.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/6_GrinderAI.s.sol:GrinderAIScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/6_GrinderAI.s.sol:GrinderAIScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract GrinderAIScript is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0x83252fE42F994Cfa62b6c29DE56aeD4AAF4F0c6f))); // address can be replaced

    IntentsNFT public intentsNFT = IntentsNFT(payable(address(0xd7A080BEC478C5152443C744fad714F45407DB21))); // address can be replaced

    GRAI public grAI = GRAI(payable(address(0))); // address can be replaced

    GrinderAI public grinderAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grinderAI = new GrinderAI();

        proxyGrinderAI = new TransparentUpgradeableProxy(address(grinderAI), deployer, "");
        grinderAI = GrinderAI(address(proxyGrinderAI));

        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI));
        
        vm.stopBroadcast();
    }
}