// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/3_Strategy1Factory.s.sol:Strategy1FactoryScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/3_Strategy1Factory.s.sol:Strategy1FactoryScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract Strategy1FactoryScript is Script {
    PoolsNFT public poolsNFT;

    Strategy1FactoryArbitrum public factory1;

    address public poolsNFTAddress = address(0); // REPASTE
    address public registryAddress = address(0); // REPASTE

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = PoolsNFT(payable(poolsNFTAddress));

        factory1 = new Strategy1FactoryArbitrum(poolsNFTAddress, registryAddress);
        poolsNFT.setStrategyFactory(address(factory1));

        vm.stopBroadcast();
    }
}
