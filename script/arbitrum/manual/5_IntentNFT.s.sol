// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {IntentNFT} from "src/IntentNFT.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/5_IntentNFT.s.sol:IntentNFTScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/5_IntentNFT.s.sol:IntentNFTScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract IntentNFTScript is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(0)); // address can be change
    
    IntentNFT public intentNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        intentNFT = new IntentNFT(address(poolsNFT));

        vm.stopBroadcast();
    }
}
