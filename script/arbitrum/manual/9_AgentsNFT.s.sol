// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { AgentsNFT } from "src/AgentsNFT.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/9_AgentsNFT.s.sol:AgentsNFTScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/9_AgentsNFT.s.sol:AgentsNFTScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract AgentsNFTScript is Script {

    AgentsNFT public agentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        agentsNFT = new AgentsNFT();
        
        vm.stopBroadcast();
    }
}