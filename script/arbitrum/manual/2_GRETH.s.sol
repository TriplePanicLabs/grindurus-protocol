// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/2_GRETH.s.sol:GRETHScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/2_GRETH.s.sol:GRETHScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract GRETHScript is Script {
    PoolsNFT public poolsNFT;

    GRETH public grETH;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = PoolsNFT(payable(address(0))/** PASTE ADDRESS */);

        grETH = new GRETH(address(poolsNFT));
        poolsNFT.setGRETH(address(grETH));


        vm.stopBroadcast();
    }
}
