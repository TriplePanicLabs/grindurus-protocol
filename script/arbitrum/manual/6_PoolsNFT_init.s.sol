// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console} from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRETH } from "src/GRETH.sol";
import { GrinderAI} from "src/GrinderAI.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/6_PoolsNFT_init.s.sol:PoolsNFTInitScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/6_PoolsNFT_init.s.sol:PoolsNFTInitScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract PoolsNFTInitScript is Script {

    address wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be changed
    
    PoolsNFTLens public poolsNFTLens = PoolsNFTLens(payable(address(0))); // address can be changed

    GRETH public grETH = GRETH(payable(address(0))); // address can be changed

    GrinderAI public grinderAI = GrinderAI(payable(address(0))); // address can be changed

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(grinderAI));
        
        vm.stopBroadcast();
    }
}