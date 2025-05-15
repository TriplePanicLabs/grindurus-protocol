// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { GRAI } from "src/GRAI.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/7_GrinderAI_init.s.sol:GrinderAIInitScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/7_GrinderAI_init.s.sol:GrinderAIInitScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract GrinderAIInitScript is Script {

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    GrinderAI public grinderAI = GrinderAI(payable(address(0))); // address can be changed

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be changed

    GRAI public grAI = GRAI(payable(address(0))); // address can be changed

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grinderAI.init(address(poolsNFT), address(grAI));
        
        vm.stopBroadcast();
    }
}