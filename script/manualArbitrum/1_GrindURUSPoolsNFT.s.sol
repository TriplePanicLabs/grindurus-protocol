// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GrindURUSPoolsNFT} from "src/GrindURUSPoolsNFT.sol";
import {GrindToken} from "src/GrindToken.sol";
import {GrindURUSPoolStrategy1, IToken, IGrindURUSPoolStrategy} from "src/strategy1/GrindURUSPoolStrategy1.sol";
import {FactoryGrindURUSPoolStrategy1} from "src/strategy1/FactoryGrindURUSPoolStrategy1.sol";

// Test purposes:
// $ forge script script/manualArbitrum/1_GrindURUSPoolsNFT.s.sol:GrindURUSPoolsNFTScript

// Mainnet deploy command:
// $ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify--slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY 


contract GrindURUSPoolsNFTScript is Script {

    GrindURUSPoolsNFT public poolsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork('arbitrum');
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new GrindURUSPoolsNFT();

        console.log("poolsNFT: ", address(poolsNFT));
        
        vm.stopBroadcast();
    }
}
