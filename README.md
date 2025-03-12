# GrindURUS Protocol

Automated onchain yield harvesting and strategy trade protocol. Fully implemented on smart contracts.

## Use Cases (whole protocol)
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

`PoolsNFT` is a smart contract that facilitates the creation and management of strategy pools represented by NFTs. It supports royalty mechanisms, deposits, withdrawals, and strategy iterations, making it a versatile tool for decentralized finance (DeFi) applications.

## Key Features
- Pool Ownership: Each NFT represents an ownership of strategy pool.
- Royalties: Configurable royalty system with shares for pool owners, grinders, and reserve funds on grETH token.
- Deposits & Withdrawals: Supports token deposits and withdrawals while enforcing caps and minimum limits to trusted actors.
- Profit Sharing: Distributes profits between participants of strategy pool
- Rebalancing: Enables efficient pool balancing across different strategies.
- Royalty Trading: Allows users to buy royalty on strategy profits.
## Core Functionalities
- Minting: Deploys a strategy pool and mints its NFT representation.
- Grind Mechanism: Rewards users with grETH for maintaining pool strategies.
- Management: Flexible configuration of deposits, royalty shares, and pool limits.

## Roles
### Owner Role
The `owner` has the highest level of authority in the contract and is responsible for administrative operations, governance, and configuration. The key responsibilities of the `owner` include:
- **Managing Strategists**: Granting and revoking strategist permissions via `setStrategiest`.
- **Configuring Royalties**: Adjusting royalty-related parameters, such as shares for pool owners, grinders, reserves, and royalty receivers, using functions like `setRoyaltyShares` and `setRoyaltyPriceShares`.
- **Updating Protocol Parameters**: Setting deposit caps (`setTokenCap`), minimum deposits (`setMinDeposit`), and other critical limits.
- **Managing Metadata**: Defining the base URI for the NFT metadata with `setBaseURI`.
- **Adding Strategies**: Listing new strategies by associating `strategyId`s with factories using `setStrategyFactory`.
- **Transferring Ownership**: Delegating contract ownership to another account, including the support for pending ownership.

### Strategiest Role
The `strategist` is a trusted user who can create, modify, and disable trading strategies. This role is crucial for managing the pool strategies and ensuring the protocol operates as intended. Responsibilities include:
- **Registering Strategies**: Deploying and associating new strategy implementations using `setStrategyFactory`.
- **Disabling Strategies**: Stopping strategies deemed invalid or harmful by calling `setStrategyStopped`.

### Agent Role
The `agent` acts as a delegate for the pool owner, authorized to perform configuration of strategy params in `URUSCore` and rebalancing strategy pools owned by `ownerOf`.
- **Rebalancing Pools**: Redistributing assets between pools with similar strategies using the `rebalance` function.
- **Configuration Operations**: Perform the changing of configuration via AI model.

### Depositor Role
The pools are isolated. The `depositor` is an account approved by the pool owner to contribute assets to a specific pool via `poolId`. This role ensures controlled access to deposits while allowing flexibility for liquidity contributions. Responsibilities include:
- **Providing Liquidity**: Depositing quote tokens into a pool via the `deposit` function.
- **Approval Management**: Ensuring that the pool owner has explicitly granted permission for deposits.

## Royalty Price Parameters
- `royaltyPriceInitNumerator`: Determines the initial royalty price as a percentage of the deposited quote token.
- `royaltyPriceCompensationShareNumerator`: Share of the royalty price allocated as compensation to the previous owner.
- `royaltyPriceReserveShareNumerator`: Share allocated to the reserve.
- `royaltyPricePoolOwnerShareNumerator`: Share allocated to the pool owner.
- `royaltyPriceGrinderShareNumerator`: Share allocated to the last grinder.

## grethShare Parameters
- `grethGrinderShareNumerator`: Share of the grinder reward allocated to the grinder (e.g., 80%).
- `grethReserveShareNumerator`: Share allocated to the reserve (e.g., 15%).
- `grethPoolOwnerShareNumerator`: Share allocated to the pool owner (e.g., 2%).
- `grethRoyaltyReceiverShareNumerator`: Share allocated to the royalty receiver (e.g., 3%).

## Royalty Parameters
- `royaltyNumerator`: Total royalty share of the profits (e.g., 20%).
- `poolOwnerShareNumerator`: Share of profits allocated to the pool owner (e.g., 80%).
- `royaltyReceiverShareNumerator`: Share of the royalty allocated to the royalty receiver.
- `royaltyReserveShareNumerator`: Share allocated to the reserve.
- `royaltyGrinderShareNumerator`: Share allocated to the last grinder.

## Parameter Changes
### Owner-only updates:
- `setBaseURI`: Update the metadata base URI.
- `setRoyaltyPriceShares`: Adjust royalty price shares.
- `setGRETHShares`: Adjust greth share distributions.
- `setRoyaltyShares`: Modify royalty distribution shares.
- `setTokenCap` and `setMinDeposit`: Configure deposit limits.
- `setStrategyFactory`: List new strategies.

### Strategiest updates:
- `setStrategyStopped`: Enable or disable strategies.

## Strategy Listing
- Register new strategy factories using `setStrategyFactory`.
- Associated with a unique `strategyId`.

## Mint Process
- Use `mint` to create a new pool:
  1. Specify `strategyId`, `quoteToken`, `baseToken`, and initial deposit.
  2. Deploy strategy contract.
  3. Mint corresponding NFT.
  4. Set royalty price for the pool.

## Deposit Process
- Approved depositors can:
  1. Call `deposit` with quote token amount.
  2. Tokens are transferred, approved, and added to pool balance.
  3. Deposit limits are enforced.

## Withdraw Process
- Pool owners can:
  - Withdraw quote tokens via `withdraw`.
  - Limited to current quote token balance.

## Exit Process
- Owners exit strategies via `exit`:
  1. Withdraw all assets.
  2. Transfer NFT to royalty receiver or protocol owner.

## Rebalance of Pools Process
- Owners or agents can:
  1. Transfer base tokens from both pools.
  2. Redistribute evenly between pools.

## Grind Process
- Execute strategy iteration with `grind`:
  1. Call `iteration` on strategy.  
  2. Awards grinder reward in `grETH`.
  3. Distributes reward among participants.

## Buy Royalty Process
- Purchase royalty rights with `buyRoyalty`:
  1. Pay new royalty price.
  2. Distribute shares among previous receiver, owner, reserve, and grinder.
  3. Refund excess funds.


# URUSCore

`URUSCore` is the core logic of the URUS trading algorithm implemented as a Solidity smart contract. It is designed to handle automated trading, hedging, and rebalancing strategies using decentralized oracles and smart contract interactions.

## Key Features
- Position Management: Supports long and hedge positions with configurable parameters.
- Profit Distribution: Tracks and distributes yield and trade profits for quoteToken and baseToken.
- Dynamic Configuration: Allows AI agents to adjust parameters like max positions, volatility, and fees.
- Investment & Rebalancing: Handles liquidity management, token swaps, and holding through lending/liquidity protocols.


---

## 1. HelperData
The `HelperData` struct contains metadata and dynamic parameters essential for the functionality of the URUS algorithm:
- **Token Decimals**: Stores decimals for `baseToken`, `quoteToken`, and `feeToken`.
- **Oracle Decimals**: Stores decimals and multipliers for price oracles.
- **Coefficient Multipliers**: Constants for fee and percentage calculations.
- **Dynamic Data**: Includes `initLiquidity` (initial liquidity) and `investCoef` (investment coefficient).

---

## 2. Fee Token
The `feeToken` is a utility token used to pay transaction fees during URUS operations. Its price is fetched via a Chainlink oracle relative to the `quoteToken`.

---

## 3. Quote Token
The `quoteToken` is the primary unit of account and settlement for trades. It is used to:
- Define the value of other tokens (e.g., `baseToken`).
- Record liquidity and calculate profitability.

---

## 4. Base Token
The `baseToken` is the asset being traded within the URUS strategy. For example, in an ETH/USDT trading pair:
- `baseToken`: ETH
- `quoteToken`: USDT

---

## 5.1 FeeConfig

The `FeeConfig` structure in the `URUSCore` contract defines parameters for calculating fees applied during trading operations. Unlike a fixed percentage, the fee coefficients (`feeCoef`) are multipliers applied to the sum of **transaction fees**, allowing dynamic scaling of fees for different operations.

Definition:
```solidity
struct FeeConfig {
    uint256 longSellFeeCoef;   // Fee for selling in a long position.
    uint256 hedgeSellFeeCoef;  // Fee for selling in a hedge position.
    uint256 hedgeRebuyFeeCoef; // Fee for rebuying during a hedge operation.
}
```

### 1. Fee Config: `longSellFeeCoef`
- **Description**: Coefficient used to calculate the fee for a `long_sell` operation.
- **Purpose**: Covers additional protocol fees for selling a long position.
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `longSellFeeCoef`.
- **Example**:
  - If `feeQty = 50` (in feeToken) and `longSellFeeCoef = 1_50`:
    \[
    \text{Total Fee} = \frac{50 \times 1.50}{100} = 75 \, \text{feeToken}.
    \]

### 2. Fee Config: `hedgeSellFeeCoef`
- **Description**: Coefficient used to calculate the fee for a `hedge_sell` operation.
- **Purpose**: Ensures coverage of costs and rewards for selling during a hedge position.
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `hedgeSellFeeCoef`.
- **Example**:
  - If `feeQty = 30` (in feeToken) and `hedgeSellFeeCoef = 2_00`:
    \[
    \text{Total Fee} = \frac{30 \times 2.00}{100} = 60 \, \text{feeToken}.
    \]

### 3. Fee Config: `hedgeRebuyFeeCoef`
- **Description**: Coefficient used to calculate the fee for a `hedge_rebuy` operation.
- **Purpose**: Covers costs associated with rebuying assets during a hedge position.
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `hedgeRebuyFeeCoef`.
- **Example**:
  - If `feeQty = 40` (in feeToken) and `hedgeRebuyFeeCoef = 1_75`:
    \[
    \text{Total Fee} = \frac{40 \times 1.75}{100} = 70 \, \text{feeToken}.
    \]

### Fee Calculation Process

Fees are calculated as follows:
1. Determine the **transaction fee** (`feeQty`) in `feeToken`. This can include:
   - Gas costs in `feeToken`.
   - Additional operational expenses.
2. Apply the corresponding fee coefficient (`feeCoef`):
   \[
   \text{Total Fee} = \frac{\text{feeQty} \times \text{feeCoef}}{\text{helper.coefMultiplier}}
   \]

## 5.2 Config

The `Config` structure in the `URUSCore` contract defines critical parameters for the operation of the URUS algorithm. These parameters control the behavior of positions, thresholds, and profit margins during trading. Adjusting these values allows authorized roles to optimize the strategy for specific market conditions.

## Structure of Config

The `Config` structure contains the following parameters:

### 1. `longNumberMax`
- **Description**: The maximum number of long positions that can be opened.
- **Purpose**: Limits the exposure to long positions, ensuring controlled investment levels.
- **Example**:
  - If `longNumberMax = 4`, a maximum of 4 sequential long positions can be opened.
  - **Scenario**: Assume the following conditions:
    - Initial investment: 100 USDT
    - `extraCoef = 2_00` (x2.00)
    - Long positions: 4 maximum
    - The investments would be:
      - Position on iteration 1: 100 USDT
      - Position on iteration 2: 200 USDT
      - Position on iteration 3: 400 USDT
      - Position on iteration 4: 800 USDT

### 2. `hedgeNumberMax`
- **Description**: The maximum number of hedge positions that can be opened.
- **Purpose**: Defines the depth of hedging during adverse market movements.
- **Example**:
  - If `hedgeNumberMax = 3`, the hedge process will stop after 3 iterations.
  - **Scenario**:
    - Total `baseToken` holdings: 16 units
    - Hedge process splits positions:
      - Hedge 1: 8 units
      - Hedge 2: 4 units
      - Hedge 3: 4 units
    - No further hedging will occur after 3 steps.

### 3. `extraCoef`
- **Description**: Multiplier used to calculate the additional liquidity required for subsequent long positions.
- **Purpose**: Ensures exponential growth of investments in long positions while maintaining proportional risk.
- **Example**:
  - If `extraCoef = 2_00` (x2.00):
    - Position 1: 100 USDT
    - Position 2: 200 USDT (100 * 2.00)
    - Position 3: 400 USDT (200 * 2.00)
    - Position 4: 800 USDT (400 * 2.00)

### 4. `priceVolatilityPercent`
- **Description**: The allowed price volatility percentage for position thresholds.
- **Purpose**: Helps define the acceptable range of price movements before triggering operations.
- **Example**:
  - If `priceVolatilityPercent = 1_00` (1%):
    - Long position threshold: If price drops by 1%, a buy order is triggered.
    - Hedge position threshold: If price rises by 1%, a hedge sell is triggered.
    - **Scenario**:
      - Base price: $1,000
      - Volatility: 1%
      - Trigger price: $990 (for buy), $1,010 (for hedge sell)

### 5. `initHedgeSellPercent`
- **Description**: The percentage used to calculate the initial hedge sell threshold.
- **Purpose**: Sets the range for initiating hedge operations.
- **Example**:
  - If `initHedgeSellPercent = 50` (0.5%):
    - Hedge sell triggers when price falls by 0.5% from the calculated threshold.
    - **Scenario**:
      - Threshold: $1,000
      - Trigger price: $995

### 6. `returnPercentLongSell`
- **Description**: The required return percentage to execute a profitable `long_sell`.
- **Purpose**: Ensures that long positions are sold only when a certain profit margin is achieved.
- **Example**:
  - If `returnPercentLongSell = 100_50` (100.5%):
    - A `long_sell` will only execute if the return is 0.5% or more above the initial investment.
    - **Scenario**:
      - Initial investment: $1,000
      - Required return: $1,005 (0.5% profit)


### 7. `returnPercentHedgeSell`
- **Description**: The required return percentage to execute a profitable `hedge_sell`.
- **Purpose**: Protects hedge positions by ensuring a minimum profit margin before selling.
- **Example**:
  - If `returnPercentHedgeSell = 100_50` (100.5%):
    - A `hedge_sell` will only execute if the return is 0.5% or more above the investment.

### 8. `returnPercentHedgeRebuy`
- **Description**: The required return percentage to execute a profitable `hedge_rebuy`.
- **Purpose**: Ensures that hedge positions are repurchased only when a certain profit margin is achievable.
- **Example**:
  - If `returnPercentHedgeRebuy = 100_50` (100.5%):
    - A `hedge_rebuy` will only execute if the return is 0.5% or more.

## Adjusting Config

Changes to the `Config` structure can only be made by authorized roles, such as the `agent`, using the following methods:

1. **`setConfig`**: Updates the entire configuration.
2. **`setLongNumberMax`**: Updates the maximum number of long positions.
3. **`setHedgeNumberMax`**: Updates the maximum number of hedge positions.
4. **`setExtraCoef`**: Updates the multiplier for liquidity calculations.
5. **`setPriceVolatilityPercent`**: Updates the allowed price volatility.
6. **`setInitHedgeSellPercent`**: Updates the initial hedge sell percentage.
7. **`setOpReturnPercent`**: Updates the return percentage for specific operations.


## 6. Long Position
The `long` position tracks data related to buying and holding `baseToken`:
- **`number`**: Current long position count.
- **`numberMax`**: Maximum allowed long positions.
- **`priceMin`**: Minimum allowable price for `baseToken` purchases.
- **`liquidity`**: Quote token liquidity in the position.
- **`qty`**: Quantity of `baseToken` held.
- **`price`**: Weighted average cost price.
- **`feeQty`**: Total fee quantity accrued in `feeToken`.
- **`feePrice`**: Fee price in terms of `quoteToken`.

---

## 7. Hedge Position
The `hedge` position tracks data for hedging against price declines:
- **`number`**: Current hedge position count.
- **`numberMax`**: Maximum allowed hedge positions.
- **`priceMin`**: Minimum price at which the hedge was initialized.
- **`liquidity`**: Quote token liquidity used in the hedge.
- **`qty`**: Quantity of `baseToken` hedged.
- **`price`**: Hedge price.
- **`feeQty`**: Total fee quantity accrued in `feeToken`.
- **`feePrice`**: Fee price in terms of `quoteToken`.

---

## 8. What Parameters Are Changeable and by Who
- **Owner**: Can modify core contract parameters, such as oracle addresses and initial configuration, via `initCore`.
- **Agent**: Can update:
  - Strategy configuration (`setConfig`).
  - Maximum long or hedge positions (`setLongNumberMax`, `setHedgeNumberMax`).
  - Volatility, fees, and thresholds (`setPriceVolatilityPercent`, `setOpFeeCoef`, etc.).

---

## 9. How Deposit Works
- **Action**: Deposit `quoteToken` into the strategy pool.
- **Steps**:
  1. `quoteToken` is transferred from the depositor.
  2. Tokens are added to the pool's liquidity balance.
  3. The deposit amount is tracked for future operations.

---

## 10. How Withdraw Works
- **Action**: Withdraw `quoteToken` from the pool.
- **Steps**:
  1. Verifies sufficient liquidity in the pool.
  2. Transfers the requested amount to the withdrawer's address.
  3. Adjusts the pool's liquidity.

---

## 11. How Exit Works
- **Action**: Exit all positions and withdraw all assets.
- **Steps**:
  1. Fetches all `baseToken` and `quoteToken` from lending protocols.
  2. Transfers tokens to the owner's address.
  3. Resets `long` and `hedge` positions to their initial state.

---

## 12. How `long_buy` Works
- **Action**: Executes a buy operation for `baseToken` in a long position.
- **Steps**:
  1. Calculates the amount of `quoteToken` required.
  2. Fetches `quoteToken` from lending protocols.
  3. Swaps `quoteToken` for `baseToken` on a DEX.
  4. Updates the long position with the new `baseToken` quantity and average price.

---

## 13. How `long_sell` Works
- **Action**: Sells all `baseToken` from a long position.
- **Steps**:
  1. Fetches all `baseToken` from lending protocols.
  2. Swaps `baseToken` for `quoteToken`.
  3. Verifies profitability based on thresholds.
  4. Distributes profits and resets the long position.

---

## 14. How `hedge_sell` Works
- **Action**: Sells `baseToken` to hedge against price declines.
- **Steps**:
  1. Calculates the `baseToken` quantity to sell.
  2. Fetches `baseToken` from lending protocols.
  3. Swaps `baseToken` for `quoteToken` on a DEX.
  4. Updates the hedge position and adjusts the long position.

---

## 15. How `hedge_rebuy` Works
- **Action**: Rebuys `baseToken` during a hedge position.
- **Steps**:
  1. Uses `quoteToken` liquidity from the hedge position.
  2. Swaps `quoteToken` for `baseToken` on a DEX.
  3. Updates the long position with the re-bought quantity.
  4. Resets the hedge position.

---

## 16. How `iterate` Works
- **Action**: Executes the appropriate trading operation based on the current state.
- **Steps**:
  1. Calls `long_buy` if no positions exist.
  2. Calls `long_sell` or `long_buy` if a long position is active.
  3. Calls `hedge_sell` or `hedge_rebuy` if hedging is active.
  4. Emits events for each operation.

---

## 17. How `beforeRebalance` and `afterRebalance` Works
### `beforeRebalance`:
- **Action**: Prepares the strategy for rebalancing.
- **Steps**:
  1. Fetches all `baseToken` from lending protocols.
  2. Transfers tokens to the rebalancing contract.
  3. Adjusts the long position accordingly.

### `afterRebalance`:
- **Action**: Updates the strategy after rebalancing.
- **Steps**:
  1. Fetches rebalanced `baseToken` from the rebalancing contract.
  2. Updates the long position with the new price and quantity.

---

## grETH

The **grETH** token is the incentivization token within the GrindURUS protocol. It rewards users (referred to as "grinders") for executing strategy iterations and serves as a mechanism to align incentives between participants and the protocol. The token is ERC-20 compliant and integrates seamlessly with the GrindURUS Pools NFT.

### **Share Calculation**
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token).
- Formula: `(Liquidity * grETH Amount) / Total Supply`


All ETH trasfers to grETH are converted to WETH.

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

Apply .env
```shell
$ source .env
```

### Arbitrum mainnet deployment
```shell
$ forge script script/DeployArbitrum.s.sol:DeployArbitrumScript --slow --broadcast --verify --verifier-url "https://api.arbiscan.io/api" --etherscan-api-key $ARBITRUMSCAN_API_KEY 
```