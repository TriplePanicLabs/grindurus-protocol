// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRETH } from "src/GRETH.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { TransparentUpgradeableProxy } from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { Agent } from "src/Agent.sol";
import { AgentsNFT } from "src/AgentsNFT.sol";
import { RegistryBase } from "src/registries/RegistryBase.sol";


// import { Strategy0Base } from "src/strategies/arbitrum/strategy0/Strategy0Base.sol";
// import { Strategy0FactoryBase } from "src/strategies/arbitrum/strategy0/Strategy0FactoryBase.sol";

import { Strategy1Base } from "src/strategies/base/strategy1/Strategy1Base.sol";
import { Strategy1FactoryBase } from "src/strategies/base/strategy1/Strategy1FactoryBase.sol";

// Test purposes:
// $ forge script script/base/DeployBase.s.sol:DeployBaseScript

// Mainnet deploy command:
// $ forge script script/base/DeployBase.s.sol:DeployBaseScript --slow --broadcast --verify --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// Verify:
// PoolsNFT
// $ forge verify-contract 0x5B42518423A7CB79A21AF455441831F36FDe823C src/PoolsNFT.sol:PoolsNFT --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// PoolsNFTLens
// $ forge verify-contract 0x4c2aA9936cc1200bB47992E2Aa3cf04bB43Cb250 src/PoolsNFTLens.sol:PoolsNFTLens --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0x5B42518423A7CB79A21AF455441831F36FDe823C")

// GRETH
// $ forge verify-contract 0x28507773E924380AA02784118034aE706F57bCEb src/GRETH.sol:GRETH --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0x5B42518423A7CB79A21AF455441831F36FDe823C" "0x4200000000000000000000000000000000000006")

// GrinderAI:
// $ forge verify-contract 0x98F464d82f55BEBCCc64dE48E4a4BD7585e320cb src/GrinderAI.sol:GrinderAI --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// TransparentUpgradeableProxy:
// $ forge verify-contract 0xf114dEfcAce38689E98A1949DB9b162208810204 lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "0x98F464d82f55BEBCCc64dE48E4a4BD7585e320cb" "0xDEC67cDDeCffdf6f45E7bC221D404eE87A720380" "0x")

// GRAI:
// $ forge verify-contract 0x2cd392CC10887a258019143a710a5Ce2C5B5d88d src/GRAI.sol:GRAI --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0x1a44076050125825900e736c501f859c50fE728c" "0xf114dEfcAce38689E98A1949DB9b162208810204")

// IntentsNFT:
// $ forge verify-contract 0x03afbDE12f4E57dbe551a2b8D7BA0F91239207Af src/IntentsNFT.sol:IntentsNFT --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0x5B42518423A7CB79A21AF455441831F36FDe823C" "0x2cd392CC10887a258019143a710a5Ce2C5B5d88d")

// RegistryBase:
// $ forge verify-contract 0x54df142Ed06B7FfEbE99E16cF9FA0c055CB21fD3 src/registries/RegistryBase.sol:RegistryBase --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0x5B42518423A7CB79A21AF455441831F36FDe823C")

// Strategy1Base
// $ forge verify-contract 0xB111D4F3493B691e44cdd6886156E72869e329c7 src/strategies/base/strategy1/Strategy1Base.sol:Strategy1Base --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// Strategy1FactoryBase
// $ forge verify-contract 0xd60a1b4d31e931454b6A085AB536db6960FC845c src/strategies/base/strategy1/Strategy1FactoryBase.sol:Strategy1FactoryBase --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0x5B42518423A7CB79A21AF455441831F36FDe823C" "0x54df142Ed06B7FfEbE99E16cF9FA0c055CB21fD3")

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/PoolStrategy1.sol:PoolStrategy1 --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// $ curl "https://api.basescan.org/api?module=contract&action=checkverifystatus&guid=qx5xfggkwzkzqyiv76wlw6benfhfmkdnuqi1ycn6bblwzhebfm&apikey=$BASESCAN_API_KEY"

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/base/strategy1/Strategy1Base.sol:Strategy1Base --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/base/strategy1/Strategy1Base.sol:Strategy1Base --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY

// $ forge verify-contract 0x9FBb0E42Db729c1C0D44cBc322b627d329A4dA46 lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain-id 8453 --verifier-url "https://api.basescan.org/api" --etherscan-api-key $BASESCAN_API_KEY


contract DeployBaseScript is Script {
    address public wethBase = 0x4200000000000000000000000000000000000006;

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointBase = 0x1a44076050125825900e736c501f859c50fE728c;

    PoolsNFT public poolsNFT;
    PoolsNFTLens public poolsNFTLens;
    GRETH public grETH;

    // GRAI public grAI;
    GrinderAI public grinderAI;
    TransparentUpgradeableProxy public proxyGrinderAI;

    RegistryBase public registry;

    Strategy1Base public strategy1;
    Strategy1FactoryBase public factory1;

    Agent public agent;
    AgentsNFT public agentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);

        vm.createSelectFork("base");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new PoolsNFT();
        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        grETH = new GRETH(address(poolsNFT), wethBase);

        grinderAI = new GrinderAI(address(poolsNFT));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(grinderAI));

        agent = new Agent();
        agentsNFT = new AgentsNFT(address(poolsNFT), address(agent));

        registry = new RegistryBase(address(poolsNFT));

        strategy1 = new Strategy1Base();
        factory1 = new Strategy1FactoryBase(address(poolsNFT), address(registry), address(strategy1));

        poolsNFT.setStrategyFactory(address(factory1));


        console.log("PoolsNFT: ", address(poolsNFT));
        console.log("PoolsNFTLens: ", address(poolsNFTLens));
        console.log("GRETH: ", address(grETH));
        console.log("GrinderAI: ", address(grinderAI));
        console.log("RegistryBase: ", address(registry));
        console.log("Strategy1: ", address(strategy1));
        console.log("Strategy1Factory: ", address(factory1));
        console.log("Agent: ", address(agent));
        console.log("AgentsNFT: ", address(agentsNFT));

        vm.stopBroadcast();
    }
}