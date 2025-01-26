# GrindURUS Protocol

Automated onchain yield harvesting and strategy trade protocol. Fully implemented on smart contracts.

## Use Cases
1. **Automated Trading**: Implements a fully automated trading strategy based on mathematical and market-driven rules.
2. **Risk Management**: Uses hedging and rebuying to mitigate losses and maintain profitability.
3. **Capital Optimization**: Maximizes efficiency by dynamically adjusting liquidity and investment levels.

## TLDR:

Architeture:
1. PoolsNFT - enumerates all strategy pools. The gateway to the standartized interaction with strategy pools.
2. URUSCore - implements all URUS algorithm logic
3. Registry - storage of quote tokens, base tokens and oracles
4. GRETH - ERC20 token that stands as incentivization for `grind` and implement the index of profit
5. Strategy - logic that utilize URUSCore + interaction with onchain protocols
6. FactoryStrategy - factory, that include strategy and deploys strategy as isolated smart contract


# PoolsNFT

The **PoolsNFT** smart contract is an ERC721 implementation representing ownership of GrindURUS strategy pools. Incorporates advanced financial mechanisms such as royalties, rebalancing, and profit-sharing for strategy actors.

## Key Features
- Pool Ownership: Each NFT represents a unique strategy pool.
- Royalties: Configurable royalty system with shares for pool owners, grinders, and reserve funds on grETH token.
- Deposits & Withdrawals: Supports token deposits and withdrawals while enforcing caps and minimum limits.
- Profit Sharing: Distributes profits in grETH (protocol token) to stakeholders.
- Rebalancing: Enables efficient pool balancing across different strategies.
- Royalty Trading: Allows users to buy and transfer royalty rights.
## Core Functionalities
- Minting: Deploys a strategy pool and mints its NFT representation.
- Grind Mechanism: Rewards users with protocol tokens for maintaining pool strategies.
- Management: Flexible configuration of deposits, royalty shares, and pool limits.


## URUSCore

The **URUSCore** smart contract implements the core logic of the URUS trading algorithm

## Key Features
- Position Management: Supports long and hedge positions with configurable parameters.
- Profit Distribution: Tracks and distributes yield and trade profits for quoteToken and baseToken.
- Dynamic Configuration: Allows AI agents to adjust parameters like max positions, volatility, and fees.
- Investment & Rebalancing: Handles liquidity management, token swaps, and rebalancing through lending protocols.


## grETH

The **grETH** token is the incentivization token within the GrindURUS protocol. It rewards users (referred to as "grinders") for executing strategy iterations and serves as a mechanism to align incentives between participants and the protocol. The token is ERC-20 compliant and integrates seamlessly with the GrindURUS Pools NFT.

### **Share Calculation**
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token).
- Formula: `(Liquidity * grETH Amount) / Total Supply`


## Registry

The **Registry** contract serves as a centralized registry for managing strategies, tokens, and oracles for DeFi protocols on the Arbitrum network. It ensures coherence between strategy pairs, quote tokens, base tokens, and their associated oracles.

### Usage Example
Adding a Strategy:
```
registry.addStrategyId(1, "MEGA Strategy");
```

Registering an Oracle:
```
registry.setOracle(quoteTokenAddress, baseTokenAddress, oracleAddress);
```

Associating a Strategy Pair:
```
registry.setStrategyPair(1, quoteTokenAddress, baseTokenAddress, true);
```

Querying Oracles:
```
address oracle = registry.getOracle(quoteTokenAddress, baseTokenAddress);
```

# Build

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