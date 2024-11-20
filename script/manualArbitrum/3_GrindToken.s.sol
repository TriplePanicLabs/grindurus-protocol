// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GrindURUSPoolsNFT} from "src/GrindURUSPoolsNFT.sol";
import {GrindToken} from "src/GrindToken.sol";
import {GrindURUSPoolStrategy1, IToken, IGrindURUSPoolStrategy} from "src/strategy1/GrindURUSPoolStrategy1.sol";
import {FactoryGrindURUSPoolStrategy1} from "src/strategy1/FactoryGrindURUSPoolStrategy1.sol";

// Test purposes:
// $ forge script script/manualArbitrum/3_GrindToken.s.sol:GrindTokenScript

// Mainnet deploy command:
// $ forge script script/manualArbitrum/3_GrindToken.s.sol:GrindTokenScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract GrindTokenScript is Script {
    GrindURUSPoolsNFT public poolsNFT = GrindURUSPoolsNFT(payable(address(0x60a8CbB469f97dC205e498eEc4B5328d1fD9B00A)));

    GrindToken public grindToken;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grindToken = new GrindToken(address(poolsNFT));

        poolsNFT.setGrindToken(address(grindToken));

        vm.stopBroadcast();
    }
}
