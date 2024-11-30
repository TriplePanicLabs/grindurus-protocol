// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GrindURUSPoolsNFT} from "src/GrindURUSPoolsNFT.sol";
import {GRETH} from "src/GRETH.sol";
import {GrindURUSPoolStrategy1, IToken, IGrindURUSPoolStrategy} from "src/strategy1/GrindURUSPoolStrategy1.sol";
import {FactoryGrindURUSPoolStrategy1} from "src/strategy1/FactoryGrindURUSPoolStrategy1.sol";
import {GrindURUSTreasury} from "src/GrindURUSTreasury.sol";

// Test purposes:
// $ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript

// Mainnet deploy command:
// $ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// Verify:
// $ forge verify-contract 0x6e0ba6683Ce4f1b575977DaF7a484341C183ec02 src/GrindURUSPoolsNFT.sol:GrindURUSPoolsNFT --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x5aA6C095981C75B1085EB447ECe5A3e544616F5b src/GRETH.sol:GRETH --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ forge verify-contract 0x307c207C0dC988f4dfe726c521e407BB64164541 src/strategy1/GrindURUSPoolStrategy1.sol:GrindURUSPoolStrategy1 --chain-id 42161 --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY

// $ curl "https://api.arbiscan.io/api?module=contract&action=checkverifystatus&guid=r8grwfdgt7dnwdp4ir3fhn17w6lbeqij3gzcyk3y1jagu99bat&apikey=$ARBITRUMSCAN_API_KEY"

contract DeployArbitrumScript is Script {
    GrindURUSPoolsNFT public poolsNFT;

    GRETH public grETH;

    FactoryGrindURUSPoolStrategy1 public factory1;

    GrindURUSTreasury public treasury;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address deployer = vm.addr(deployerPrivateKey);
        console.log(deployer);

        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployerPrivateKey);

        poolsNFT = new GrindURUSPoolsNFT();

        grETH = new GRETH(address(poolsNFT));
        poolsNFT.setGRETH(address(grETH));

        treasury = new GrindURUSTreasury(address(poolsNFT));
        poolsNFT.setTreasury(address(treasury));

        factory1 = new FactoryGrindURUSPoolStrategy1(address(poolsNFT));
        poolsNFT.setFactoryStrategy(address(factory1));

        vm.stopBroadcast();
    }
}
