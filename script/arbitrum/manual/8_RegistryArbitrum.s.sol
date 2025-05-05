// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/8_RegistryArbitrum.s.sol:RegistryArbitrumScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/8_RegistryArbitrum.s.sol:GRETHScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract RegistryArbitrumScript is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0)));

    RegistryArbitrum public registry;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        registry = RegistryArbitrum(address(poolsNFT));

        vm.stopBroadcast();
    }
}
