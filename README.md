# GrindURUS Protocol

Automated onchain yield harvesting and strategy trade protocol.
Architecture of smart contracts consist of NFT, factory that deploys noncastodial strategy pool and GRIND ERC20 token.


## Build

Initialize firstly .env
```shell
$ cp .env.example .env
```

```shell
$ forge build
```

## Run Tests

```shell
$ forge test
```

## Deployment

The deployment is implemented in scripts and handled by foundry framework.

# Testing workablity of deployment
```shell
$ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript
```

### Arbitrum mainnet deployment
```shell
$ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY 
```