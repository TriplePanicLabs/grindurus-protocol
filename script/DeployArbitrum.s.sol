// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GrindURUSPoolsNFT} from "src/GrindURUSPoolsNFT.sol";
import {GrindToken} from "src/GrindToken.sol";
import {GrindURUSPoolStrategy1, IToken, IGrindURUSPoolStrategy} from "src/strategy1/GrindURUSPoolStrategy1.sol";
import {FactoryGrindURUSPoolStrategy1} from "src/strategy1/FactoryGrindURUSPoolStrategy1.sol";

// Test purposes:
// $ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript

// Mainnet deploy command:
// $ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY 

contract DeployArbitrumScript is Script {

    GrindURUSPoolsNFT public poolsNFT;

    GrindToken public grindToken;

    FactoryGrindURUSPoolStrategy1 public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork('arbitrum');
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new GrindURUSPoolsNFT();

        grindToken = new GrindToken(address(poolsNFT));
        poolsNFT.setGrindToken(address(grindToken));

        factory1 = new FactoryGrindURUSPoolStrategy1(address(poolsNFT));
        poolsNFT.setFactoryStrategy(address(factory1));

        vm.stopBroadcast();
    }
}
