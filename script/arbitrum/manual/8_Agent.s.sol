// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { Agent } from "src/Agent.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/8_Agent.s.sol:AgentScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/8_Agent.s.sol:AgentScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract AgentScript is Script {

    Agent public agent;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        agent = new Agent();
        
        vm.stopBroadcast();
    }
}