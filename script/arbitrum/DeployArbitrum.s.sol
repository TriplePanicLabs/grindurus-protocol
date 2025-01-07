// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PoolsNFT} from "src/PoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {Strategy1Arbitrum, IToken, IStrategy} from "src/strategies/arbitrum/strategy1/Strategy1Arbitrum.sol";
import {Strategy1FactoryArbitrum} from "src/strategies/arbitrum/strategy1/Strategy1FactoryArbitrum.sol";
import {RegistryArbitrum} from "src/registries/RegistryArbitrum.sol";


// Test purposes:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript

// Mainnet deploy command:
// $ forge script script/arbitrum/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// Verify:
// $ forge verify-contract 0x6e0ba6683Ce4f1b575977DaF7a484341C183ec02 src/PoolsNFT.sol:PoolsNFT --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x5aA6C095981C75B1085EB447ECe5A3e544616F5b src/GRETH.sol:GRETH --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/PoolStrategy1.sol:PoolStrategy1 --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ curl "https://api.arbiscan.io/api?module=contract&action=checkverifystatus&guid=r8grwfdgt7dnwdp4ir3fhn17w6lbeqij3gzcyk3y1jagu99bat&apikey=$ARBITRUMSCAN_API_KEY"

// $ forge verify-contract 0x0CCD1B1a42dbc5baBb53dF800BE8821f4d3411aA src/arbitrum/strategy1/Strategy1Arbitrum.sol:Strategy1Arbitrum --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY


contract DeployArbitrumScript is Script {
    PoolsNFT public poolsNFT;

    GRETH public grETH;

    RegistryArbitrum public registry;

    Strategy1FactoryArbitrum public factory1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new PoolsNFT();

        grETH = new GRETH(address(poolsNFT));
        poolsNFT.setGRETH(address(grETH));

        registry = new RegistryArbitrum(address(poolsNFT));

        factory1 = new Strategy1FactoryArbitrum(address(poolsNFT), address(registry));
        poolsNFT.setStrategyFactory(address(factory1));

        vm.stopBroadcast();
    }
}
