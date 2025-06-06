// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { RegistryArbitrum } from "src/registries/RegistryArbitrum.sol";
import { Strategy1Arbitrum } from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import { Strategy1FactoryArbitrum } from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/9_Strategy1Factory.s.sol:Strategy1FactoryScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/9_Strategy1Factory.s.sol:Strategy1FactoryScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract Strategy1FactoryScript is Script {

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be change
    
    Strategy1Arbitrum public strategy1 = Strategy1Arbitrum(payable(address(0))); // address can be change
    
    RegistryArbitrum public registry = RegistryArbitrum(address(0)); // address can be change

    Strategy1FactoryArbitrum public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);
        
        strategy1 = new Strategy1Arbitrum();
        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry), address(strategy1));
        poolsNFT.setStrategyFactory(address(factory1));

        vm.stopBroadcast();
    }
}
