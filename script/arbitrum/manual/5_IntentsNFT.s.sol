// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/5_IntentsNFT.s.sol:IntentsNFTScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/5_IntentsNFT.s.sol:IntentsNFTScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract IntentsNFTScript is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(0x83252fE42F994Cfa62b6c29DE56aeD4AAF4F0c6f)); // address can be change
    
    IntentsNFT public intentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        intentsNFT = new IntentsNFT(address(poolsNFT));

        vm.stopBroadcast();
    }
}
