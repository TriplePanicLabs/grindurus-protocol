// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {PoolStrategy1, IToken, IPoolStrategy} from "src/strategy1/PoolStrategy1.sol";
import {FactoryPoolStrategy1} from "src/strategy1/FactoryPoolStrategy1.sol";

// Test purposes:
// $ forge script script/manualArbitrum/2_FactoryPoolStrategy1.s.sol:FactoryPoolStrategy1Script

// Mainnet deploy command:
// $ forge script script/manualArbitrum/2_FactoryPoolStrategy1.s.sol:FactoryPoolStrategy1Script --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract <address of FactoryPoolStrategy1> src/strategy1/FactoryPoolStrategy1.sol:FactoryPoolStrategy1 --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

contract FactoryPoolStrategy1Script is Script {
    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0x60a8CbB469f97dC205e498eEc4B5328d1fD9B00A)));

    FactoryPoolStrategy1 public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        factory1 = new FactoryPoolStrategy1(address(poolsNFT));

        poolsNFT.setFactoryStrategy(address(factory1));

        vm.stopBroadcast();
    }
}
