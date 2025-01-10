// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy0Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy0/Strategy0Arbitrum.sol";
import {Strategy0FactoryArbitrum} from "src/strategies/arbitrum/strategy0/Strategy0FactoryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/3_Strategy0Factory.s.sol:Strategy0FactoryScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/3_Strategy0Factory.s.sol:Strategy0FactoryScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract Strategy0FactoryScript is Script {
    PoolsNFT public poolsNFT;

    Strategy0FactoryArbitrum public factory0;

    address public poolsNFTAddress = address(0); // REPASTE
    address public oracleRegistryAddress = address(0); // REPASTE

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = PoolsNFT(payable(poolsNFTAddress));

        factory0 = new Strategy0FactoryArbitrum(poolsNFTAddress, oracleRegistryAddress);
        poolsNFT.setStrategyFactory(address(factory0));

        vm.stopBroadcast();
    }
}
