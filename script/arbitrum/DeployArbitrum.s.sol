// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {GrinderAI} from "src/GrinderAI.sol";

// Test purposes:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript

// Mainnet deploy command:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// Verify:
// $ forge verify-contract 0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db src/PoolsNFT.sol:PoolsNFT --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0xae4312A2E0D15550B0cD9889B2aF56a520589E53 src/GRETH.sol:GRETH --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db" "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")

// $ forge verify-contract 0x8BCC8B5Cd7e9E0138896A82E6Db7b55b283EbBcB src/registries/RegistryArbitrum.sol:RegistryArbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db")

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/PoolStrategy1.sol:PoolStrategy1 --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ curl "https://api.arbiscan.io/api?module=contract&action=checkverifystatus&guid=qx5xfggkwzkzqyiv76wlw6benfhfmkdnuqi1ycn6bblwzhebfm&apikey=$ARBITRUMSCAN_API_KEY"

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol:Strategy1Arbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol:Strategy1Arbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x9FBb0E42Db729c1C0D44cBc322b627d329A4dA46 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract DeployArbitrumScript is Script {
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;

    GRETH public grETH;

    IntentsNFT public intentsNFT;

    GrinderAI public grinderAI;

    RegistryArbitrum public registry;

    Strategy1Arbitrum public strategy1;

    Strategy1FactoryArbitrum public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new PoolsNFT();

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        grETH = new GRETH(address(poolsNFT), weth);

        intentsNFT = new IntentsNFT(address(poolsNFT));

        grinderAI = new GrinderAI();
        grinderAI.init(address(poolsNFT), address(intentsNFT));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(grinderAI));

        registry = new RegistryArbitrum(address(poolsNFT));

        strategy1 = new Strategy1Arbitrum();
        
        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry));
        factory1.setStrategyImplementation(address(strategy1));

        poolsNFT.setStrategyFactory(address(factory1));

        console.log("PoolsNFT: ", address(poolsNFT));
        console.log("PoolsNFTLens: ", address(poolsNFTLens));
        console.log("GRETH: ", address(grETH));
        console.log("IntentsNFT: ", address(intentsNFT));
        console.log("GrinderAI: ", address(grinderAI));
        console.log("RegistryArbitrum: ", address(registry));
        console.log("Strategy1: ", address(strategy1));
        console.log("Factory1: ", address(factory1));

        vm.stopBroadcast();
    }
}
