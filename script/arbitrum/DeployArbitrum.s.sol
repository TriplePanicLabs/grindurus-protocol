// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { PoolsNFT } from "src/PoolsNFT.sol";
import { PoolsNFTLens } from "src/PoolsNFTLens.sol";
import { GRETH } from "src/GRETH.sol";
import { GrinderAI } from "src/GrinderAI.sol";
import { Agent } from "src/Agent.sol";
import { AgentsNFT } from "src/AgentsNFT.sol";
import { RegistryArbitrum } from "src/registries/RegistryArbitrum.sol";

import { Strategy0Arbitrum } from "src/strategies/arbitrum/strategy0/Strategy0Arbitrum.sol";
import { Strategy0FactoryArbitrum } from "src/strategies/arbitrum/strategy0/Strategy0FactoryArbitrum.sol";

import { Strategy1Arbitrum } from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import { Strategy1FactoryArbitrum } from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";

// Test purposes:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript

// Mainnet deploy command:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// Verify:
// $ forge verify-contract 0x2915F020C1eAF94dfaCa576914dA829231178a13 src/PoolsNFT.sol:PoolsNFT --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x80140D46F7491C26d02938759D7Dc345e73080Ea src/PoolsNFTLens.sol:PoolsNFTLens --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0x2915F020C1eAF94dfaCa576914dA829231178a13")

// $ forge verify-contract 0x5399084C72671555D7576E2A0842b250A7C05b92 src/GRETH.sol:GRETH --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address,address)" "0x2915F020C1eAF94dfaCa576914dA829231178a13" "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")

// $ forge verify-contract 0x8BCC8B5Cd7e9E0138896A82E6Db7b55b283EbBcB src/registries/RegistryArbitrum.sol:RegistryArbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" "0xfC7a86Ab7c0E48F26F3aEe7382eBc6fe313956Db")

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/PoolStrategy1.sol:PoolStrategy1 --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ curl "https://api.arbiscan.io/api?module=contract&action=checkverifystatus&guid=qx5xfggkwzkzqyiv76wlw6benfhfmkdnuqi1ycn6bblwzhebfm&apikey=$ARBITRUMSCAN_API_KEY"

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol:Strategy1Arbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x371194617A7a7f6605c79a80a9EB0EB05C4E75dA src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol:Strategy1Arbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0xf0A7B3E0DA1eB030B44e370cF1E01101265831ac lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract DeployArbitrumScript is Script {
    address public wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // https://docs.layerzero.network/v2/deployments/deployed-contracts
    address lzEndpointArbitrum = 0x1a44076050125825900e736c501f859c50fE728c;

    PoolsNFT public poolsNFT;
    PoolsNFTLens public poolsNFTLens;

    GRETH public grETH;

    GrinderAI public grinderAI;

    RegistryArbitrum public registry;

    Strategy1Arbitrum public strategy1;
    Strategy1FactoryArbitrum public factory1;

    Agent public agent;
    AgentsNFT public agentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new PoolsNFT();
        poolsNFTLens = new PoolsNFTLens(address(poolsNFT));
        
        grETH = new GRETH(address(poolsNFT), wethArbitrum);

        grinderAI = new GrinderAI(address(poolsNFT));

        poolsNFT.init(address(poolsNFTLens), address(grETH), address(grinderAI));

        registry = new RegistryArbitrum(address(poolsNFT));

        strategy1 = new Strategy1Arbitrum();
        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry), address(strategy1));

        poolsNFT.setStrategyFactory(address(factory1));

        // agent = new Agent();
        // agentsNFT = new AgentsNFT(address(poolsNFT), address(agent));

        console.log("PoolsNFT: ", address(poolsNFT));
        console.log("PoolsNFTLens: ", address(poolsNFTLens));
        console.log("GRETH: ", address(grETH));
        console.log("GrinderAI: ", address(grinderAI));
        console.log("RegistryArbitrum: ", address(registry));
        console.log("Strategy1: ", address(strategy1));
        console.log("Strategy1Factory: ", address(factory1));
        // console.log("Agent: ", address(agent));
        // console.log("AgentsNFT: ", address(agentsNFT));

        vm.stopBroadcast();
    }
}

// Test purposes:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployAgentsArbitrumScript

// Mainnet deploy command: (without verification)
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployAgentsArbitrumScript --slow --broadcast

contract DeployAgentsArbitrumScript is Script {

    PoolsNFT public poolsNFT = PoolsNFT(payable(address(0)));

    Agent public agent;
    AgentsNFT public agentsNFT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        require(address(poolsNFT) != address(0), "NOT INSTANTIATED POOLSNFT");
        agent = new Agent();
        agentsNFT = new AgentsNFT(address(poolsNFT), address(agent));

        console.log("Agent: ", address(agent));
        console.log("AgentsNFT: ", address(agentsNFT));
        
        vm.stopBroadcast();
    }
}