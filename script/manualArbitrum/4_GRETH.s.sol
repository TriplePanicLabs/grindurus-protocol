// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {PoolStrategy1, IToken, IPoolStrategy} from "src/strategy1/PoolStrategy1.sol";
import {FactoryPoolStrategy1} from "src/strategy1/FactoryPoolStrategy1.sol";

// Test purposes:
// $ forge script script/manualArbitrum/3_GrindToken.s.sol:GrindTokenScript

// Mainnet deploy command:
// $ forge script script/manualArbitrum/3_GrindToken.s.sol:GrindTokenScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract <address of GRETH> src/GRETH.sol:GRETH --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract GrindTokenScript is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0x60a8CbB469f97dC205e498eEc4B5328d1fD9B00A)));

    GRETH public grETH;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        grETH = new GRETH(address(poolsNFT));

        poolsNFT.setGRETH(address(grETH));

        vm.stopBroadcast();
    }
}
