// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";

import {Strategy1Base, IToken, IStrategy} from "src/strategies/base/strategy1/Strategy1Base.sol";
import {Strategy1FactoryBase} from "src/strategies/base/strategy1/Strategy1FactoryBase.sol";
import {RegistryBase} from "src/registries/RegistryBase.sol";
import {IntentsNFT} from "src/IntentsNFT.sol";
import {PoolsNFTLens} from "src/PoolsNFTLens.sol";
import {GRAI} from "src/GRAI.sol";
import {GrinderAI} from "src/GrinderAI.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Test purposes:
// $ forge script script/base/DeployBase.s.sol:DeployBaseScript

// Mainnet deploy command:
// $ forge script script/base/DeployBase.s.sol:DeployBaseScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY

// Verify:
// $ forge verify-contract 0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db src/PoolsNFT.sol:PoolsNFT --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY

// $ forge verify-contract 0xae4312A2E0D15550B0cD9889B2aF56a520589E53 src/GRETH.sol:GRETH --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db" "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")

// $ forge verify-contract 0x8BCC8B5Cd7e9E0138896A82E6Db7b55b283EbBcB src/registries/RegistryBase.sol:RegistryBase --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db")

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/PoolStrategy1.sol:PoolStrategy1 --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY

// $ curl "https://api.arbiscan.io/api?module=contract&action=checkverifystatus&guid=qx5xfggkwzkzqyiv76wlw6benfhfmkdnuqi1ycn6bblwzhebfm&apikey=$BASESCAN_API_KEY"

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/base/strategy1/Strategy1Base.sol:Strategy1Base --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/base/strategy1/Strategy1Base.sol:Strategy1Base --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY

// $ forge verify-contract 0x9FBb0E42Db729c1C0D44cBc322b627d329A4dA46 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain-id 8453 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $BASESCAN_API_KEY


contract DeployBaseScript is Script {
    address public wethBase = 0x4200000000000000000000000000000000000006;

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointBase = 0x1a44076050125825900e736c501f859c50fE728c;

    PoolsNFT public poolsNFT;

    PoolsNFTLens public poolsNFTLens;

    GRETH public grETH;

    IntentsNFT public intentsNFT;

    GRAI public grAI;

    GrinderAI public grinderAI;

    TransparentUpgradeableProxy public proxyGrinderAI;

    RegistryBase public registry;

    Strategy1Base public strategy1;

    Strategy1FactoryBase public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("base");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new PoolsNFT();

        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        grETH = new GRETH(address(poolsNFT), wethBase);

        grinderAI = new GrinderAI();
        proxyGrinderAI = new TransparentUpgradeableProxy(address(grinderAI), deployer, "");
        
        grAI = new GRAI(lzEndpointBase, address(proxyGrinderAI));

        intentsNFT = new IntentsNFT(address(poolsNFT), address(grAI));

        grinderAI = GrinderAI(payable(proxyGrinderAI));
        grinderAI.init(address(poolsNFT), address(intentsNFT), address(grAI));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(proxyGrinderAI));

        registry = new RegistryBase(address(poolsNFT));

        strategy1 = new Strategy1Base();
        
        factory1 = new Strategy1FactoryBase(address(poolsNFT), address(registry));
        factory1.setStrategyImplementation(address(strategy1));

        poolsNFT.setStrategyFactory(address(factory1));

        console.log("PoolsNFT: ", address(poolsNFT));
        console.log("PoolsNFTLens: ", address(poolsNFTLens));
        console.log("GRETH: ", address(grETH));
        console.log("GrinderAI: ", address(grinderAI));
        console.log("GRAI: ", address(grAI));
        console.log("IntentsNFT: ", address(intentsNFT));
        console.log("RegistryBase: ", address(registry));
        console.log("Strategy1: ", address(strategy1));
        console.log("Strategy1Factory: ", address(factory1));

        vm.stopBroadcast();
    }
}
