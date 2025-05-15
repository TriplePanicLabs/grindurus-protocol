// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { AgentsNFT } from "src/AgentsNFT.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/9_AgentsNFT.s.sol:AgentsNFTScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/9_AgentsNFT.s.sol:AgentsNFTScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract AgentsNFTScript is Script {

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be changed

    address public initialAgentImplementation = address(0);

    AgentsNFT public agentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        agentsNFT = new AgentsNFT(address(poolsNFT),initialAgentImplementation);
        
        vm.stopBroadcast();
    }
}