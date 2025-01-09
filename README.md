# GrindURUS Protocol

Automated onchain yield harvesting and strategy trade protocol.
Architecture of smart contracts consist of NFT, factory that deploys noncastodial strategy and grETH ERC20 token.

# PoolsNFT
The **PoolsNFT** smart contract is designed to represent ownership of strategies and pools in the GrindURUS protocol. Each NFT serves as a unique identifier for a pool and provides various functionalities to interact with the pool's underlying strategy.

## Key Features
### 1. **NFT Representation**
- Each pool in the GrindURUS protocol is uniquely represented by an ERC-721 NFT.
- These NFTs provide a decentralized and transparent way to manage ownership of pools and strategies.

### 2. **Dynamic Royalty System**
- Implements a flexible royalty system that adjusts dynamically based on pool activity.
- Configurable royalty shares are distributed among various stakeholders, such as pool owners, grinders (users executing pool strategies), royalty receivers, and reserve (grETH).
- Royalties are calculated in compliance with the ERC-2981 standard, ensuring compatibility with marketplaces.

### 3. **Customizable Pool Strategies**
- Supports deployment of customizable strategies upon minting an NFT.
- Strategies are deployed as independent smart contracts linked to the NFT, enabling modular and scalable architecture.

### 4. **Asset Management**
- Allows pool owners to deposit and withdraw assets in a secure and controlled manner.
- Implements configurable parameters, such as minimum and maximum deposit limits, as well as total value caps for each pool.

### 5. **Rebalancing Pools**
- Enables rebalancing of assets between compatible pools owned by the same user.
- Rebalancing ensures optimal capital allocation and strategy execution across pools.

### 6. **grETH Incentives**
- Rewards users executing strategy iterations ("grinding") with `grETH` tokens.
- Distributes `grETH` rewards among stakeholders based on a predefined share system.

### 7. **Security and Compliance**
- Utilizes OpenZeppelin libraries for enhanced security:
  - `ReentrancyGuard` prevents reentrancy attacks in `buyRoyalty` function
  - `SafeERC20` ensures safe interaction with ERC-20 tokens.
- Implements robust error handling and input validation to ensure reliability and security.

### 8. **Comprehensive Metadata**
- Provides token metadata through a base URI, enabling integration with decentralized applications (dApps) and marketplaces.
- Metadata can be dynamically generated or hosted off-chain.

## Contract Details
### **Standards and Libraries**
- Built on the ERC-721 standard with enumerable functionality, ensuring compatibility with NFT ecosystems.
- Implements the ERC-2981 royalty standard for seamless integration with NFT marketplaces.
- Uses OpenZeppelin's utility libraries (`Strings`, `Base64`, etc.) to streamline development and improve security.

### **Royalty System**
- Flexible royalty configuration for pool owners, grinders, reserves, and royalty receivers.
- Royalty prices always increase, ensuring a predictable value trajectory.
- Supports buying and transferring royalty rights, with strict checks to prevent underpayment or misuse.

### **Deposits and Withdrawals**
- Configurable deposit limits:
  - **Maximum Deposit**: Defines the upper limit for asset deposits into a pool.
  - **Minimum Deposit**: Ensures a base threshold for deposits.
  - **Token Cap**: Sets a maximum total value for a specific token in a pool.
- Withdrawals can only be executed by the NFT owner, ensuring secure asset management.

### **Rebalancing**
- Enables rebalancing of asset allocations across pools owned by the same user.
- Rebalancing ensures consistency in strategy execution while optimizing asset distribution.

### **Strategy Management**
- Pool strategies are implemented as separate smart contracts deployed during NFT minting.
- Strategies can define custom rules for trading, yield generation, and capital allocation.
- Provides APIs for interacting with strategies, including depositing, withdrawing, and grinding.

### **Dynamic Metadata**
- Supports dynamic metadata retrieval via `tokenURI`.
- Integrates with third-party services for on-chain or off-chain metadata generation.


### **Stakeholder Shares**
- Configurable share distribution for profits, royalties, and rewards:
  - **Pool Owner**: Majority share of profits.
  - **Royalty Receiver**: Fixed share of royalties.
  - **Last Grinder**: Incentive for executing pool iterations.
  - **Reserve (grETH)**: Ensures stability and growth of the protocol.

## Roles and Permissions
### 1. **Owner**
- The protocol owner has administrative rights over the contract.
- Responsibilities:
  - Setting royalty and grETH share configurations.
  - Managing strategy factories and deployment parameters.
  - Updating contract parameters, such as deposit limits and base URI.

### 2. **Pool Owner**
- The owner of a pool NFT, representing control over the associated strategy.
- Responsibilities:
  - Managing deposits and withdrawals.
  - Rebalancing assets between owned pools.
  - Exiting strategies and receiving remaining assets.

### 3. **Grinder**
- Users who execute the pool's strategy iterations by calling the `grind` function.
- Incentives:
  - Rewarded with `grETH` tokens for their computational contribution.
  - Shares of profits generated during iterations.

### 4. **Royalty Receiver**
- The entity entitled to a portion of royalties from the pool.
- Rights:
  - Can transfer or sell royalty ownership through the `buyRoyalty` function.

### 5. **Reserve(grETH)**
- A share of royalties is allocated to the protocol's reserve.
- Purpose:
  - Ensures protocol sustainability and long-term growth and incentivise to `grind`.

### 6. **Strategy Factory**
- Entities responsible for deploying and managing pool strategies.
- Responsibilities:
  - Implementing customizable strategies compatible with the GrindURUS protocol.
  - Providing unified APIs for interaction with pool strategies.


# GrindURUS Token (grETH)

## Overview
The **GrindURUS ETH (grETH)** token is the incentivization token within the GrindURUS protocol. It rewards users (referred to as "grinders") for executing strategy iterations and serves as a mechanism to align incentives between participants and the protocol. The token is ERC-20 compliant and integrates seamlessly with the GrindURUS Pools NFT.

## Key Features

### 1. **Incentivization for Grinding**
- **Purpose**: grETH tokens are minted as a reward for users who execute strategy iterations on pools (`grind` function).
- **Distribution**: Tokens are distributed to multiple stakeholders based on a predefined share system configured in the PoolsNFT contract.

### 2. **ERC-20 Compliance**
- Fully adheres to the ERC-20 token standard, making it compatible with wallets, decentralized exchanges, and other DeFi protocols.

### 3. **Minting Mechanism**
- **Controlled Minting**: Only the PoolsNFT contract can mint grETH tokens, ensuring that token issuance is tied directly to protocol activity.
- **Tracking**: Tracks the total number of grETH tokens minted and the distribution among individual participants.

### 4. **Burning and Redemption**
- **Burn Functionality**: Users can burn their grETH tokens to redeem underlying assets (e.g., native tokens or ERC-20 tokens) held in the grETH contract.
- **Proportional Redemption**: The amount redeemed is proportional to the user’s grETH share relative to the total supply.

### 5. **Liquidity Backing**
- **Backed by Assets**: grETH tokens are backed by the assets held in the contract, including native tokens (e.g., ETH) and ERC-20 tokens.
- **Dynamic Valuation**: The value of grETH is determined by the liquidity available in the contract and the total supply of grETH tokens.

### 6. **Integration with PoolsNFT**
- **Ownership Links**: The `poolsNFT` contract governs grETH minting and links it to specific pool activities.
- **Protocol Ownership**: The protocol owner (from PoolsNFT) has specific rights to manage liquidity and interact with grETH.

### 7. **Security Features**
- Utilizes OpenZeppelin's `SafeERC20` for secure token transfers.
- Implements robust error handling for minting, burning, and liquidity operations to ensure protocol reliability.

## Contract Details

### **Share Calculation**
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token).
- Formula: `(Liquidity * grETH Amount) / Total Supply`

### **Ownership**
- Ownership of the grETH contract is linked to the PoolsNFT contract or its designated protocol owner.
- The `owner` function dynamically resolves the protocol owner to ensure alignment with the broader GrindURUS ecosystem.

### **Tracking and Metrics**
- `totalGrinded`: Tracks the total number of grETH tokens minted through grinding.
- `totalMintedBy`: Records the amount of grETH minted by each participant.

## Use Cases
1. **Incentive Rewards**: grETH tokens incentivize participants to execute strategy iterations, ensuring active protocol engagement.
2. **Value Redemption**: Provides users with a mechanism to convert grETH into tangible assets, making the token inherently valuable.
3. **Ecosystem Growth**: Aligns participant incentives with the protocol’s success, fostering sustainable growth.


# URUS Core Smart Contract

## Overview
The **URUS Core** contract implements the fundamental logic of the URUS trading algorithm. It orchestrates the interaction between tokens, price oracles, and lending platforms to execute advanced trading strategies such as long buying, long selling, hedging, and rebalancing. Designed for high scalability and customization, URUS Core serves as the backbone of the GrindURUS protocol's trading operations.

## Key Features

### 1. **Dynamic Trading Strategy**
- Executes trading strategies based on user-defined configurations:
  - **Long Buying**: Accumulates base tokens by converting quote tokens.
  - **Long Selling**: Realizes profits by selling accumulated base tokens.
  - **Hedging**: Protects positions by selling base tokens at defined thresholds.
  - **Rebuying**: Reacquires base tokens after hedging to restore the initial position.

### 2. **Configurable Parameters**
- Highly customizable strategy configurations, such as:
  - Maximum long positions (`longNumberMax`) and hedging steps (`hedgeNumberMax`).
  - Price volatility thresholds (`priceVolatility`).
  - Return on investment targets for various operations (`returnPercentLongSell`, `returnPercentHedgeSell`, `returnPercentHedgeRebuy`).
  - Initial liquidity and investment coefficients.

### 3. **Price Oracle Integration**
- Uses Chainlink price oracles for accurate price feeds of tokens in the strategy:
  - Quote token price in terms of fee token.
  - Quote token price in terms of base token.
- Facilitates real-time decision-making for trades based on market conditions.

### 4. **Lending Integration**
- Interacts with lending protocols for asset management:
  - Deposits and withdraws tokens as part of strategy execution.
  - Maximizes capital efficiency by leveraging lent assets.

### 5. **Profit Distribution**
- Tracks and distributes profits from both yield and trade operations.
- Configurable profit-sharing for long positions, hedge positions, and rebuy operations.

### 6. **Rebalancing Support**
- Enables rebalancing of positions across multiple pools.
- Facilitates optimal capital allocation and strategy alignment.

### 7. **Advanced Calculation Functions**
- Provides a suite of calculation methods to ensure precision in trading:
  - Thresholds for profitable trades.
  - Target prices for hedging and rebuys.
  - Liquidity and investment coefficients.

### 8. **Security and Access Control**
- Implements multiple access layers for security:
  - **Owner**: Configures strategy parameters and agent access.
  - **Agent**: Executes core strategy functions like setting parameters and thresholds.
  - **Trusted Gateway**: Handles deposits, withdrawals, and position exits.
- Uses OpenZeppelin’s `SafeERC20` for secure token operations.

---

## Contract Components

### **Core Variables**
- **Tokens**: Manages the three core tokens in the strategy:
  - `feeToken`: Used to handle transaction fees.
  - `quoteToken`: Primary trading token.
  - `baseToken`: Asset being traded.
- **Oracles**: Price feeds for `feeToken` and `baseToken` relative to `quoteToken`.
- **Positions**:
  - `long`: Tracks parameters of long positions.
  - `hedge`: Tracks parameters of hedge position.
- **Helper Data**:
  - Decimals, multipliers, and liquidity coefficients for precise calculations for optimization.

### **Trading Operations**
1. **Long Buying**:
   - Uses quote tokens to buy base tokens.
   - Updates position parameters such as price, quantity, and liquidity.
   - Ensures price volatility thresholds are respected.

2. **Long Selling**:
   - Converts base tokens back into quote tokens.
   - Distributes profits and fees before closing the position.
   - Requires all hedging operations to be completed before execution.

3. **Hedge Selling**:
   - Sells portions of base tokens to mitigate risk.
   - Initializes or continues a hedging strategy based on price thresholds.
   - Distributes profits and updates position parameters.

4. **Hedge Rebuying**:
   - Reacquires base tokens after a hedging operation.
   - Ensures profitability thresholds are met.

### **Rebalancing**
- Provides `beforeRebalance` and `afterRebalance` methods to manage position adjustments between pools.
- Ensures consistency in position sizes and prices across pools.

---

## Workflow Example
1. **Initialization**:
   - Deploy the contract and call `initCore` with token addresses, oracles, and strategy configuration.
   - Set agents and trusted gateways for executing strategy operations.

2. **Execution**:
   - Call `iterate` to execute the trading strategy automatically.
   - The algorithm determines whether to buy, sell, hedge, or rebuy based on current market conditions and position states.

3. **Profit Distribution**:
   - Track profits in `totalProfits` and distribute them automatically during trading operations.

4. (Optional)**Rebalancing**:
   - Use the rebalancing functions to redistribute assets between pools.

---

## Use Cases
1. **Automated Trading**: Implements a fully automated trading strategy based on mathematical and market-driven rules.
2. **Risk Management**: Uses hedging and rebuying to mitigate losses and maintain profitability.
3. **Capital Optimization**: Maximizes efficiency by dynamically adjusting liquidity and investment levels.


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