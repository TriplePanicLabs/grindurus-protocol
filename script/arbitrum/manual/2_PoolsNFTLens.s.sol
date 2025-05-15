// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";

// Test purposes:
// $ forge script script/arbitrum/manual/2_PoolsNFTLens.s.sol:PoolsNFTLensScript

// Mainnet deploy command:
// $ forge script script/arbitrum/manual/2_PoolsNFTLens.s.sol:PoolsNFTLensScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract PoolsNFTLensScript is Script {

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0))); // address can be replaced

    PoolsNFTLens public poolsNFTLens;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));

        vm.stopBroadcast();
    }
}
