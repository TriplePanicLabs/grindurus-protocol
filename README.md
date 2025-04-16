# GrindURUS Protocol

Automated Market Taker

Onchain yield harvesting and strategy trade protocol.

## Use Cases (whole protocol)
1. **Automated Trading**: Implements a fully automated trading strategy based on mathematical and market-driven rules.
2. **Risk Management**: Uses hedging and rebuying to mitigate unrealized loss
3. **Capital Optimization**: Maximizes efficiency by dynamically adjusting liquidity and investment levels.

## Architecture TLDR:

Architeture:
1. PoolsNFT - enumerates all strategy pools. The gateway to the standartized interaction with strategy pools.
2. PoolsNFTLens - lens contract that retrieves data from PoolsNFT and Strategies
3. URUS - implements all URUS algorithm logic
4. Registry - storage of quote tokens, base tokens and oracles
5. GRETH - ERC20 token that stands as incentivization for `grind` and implements the index of collected profit
6. Strategy - logic that utilize URUS + interaction with onchain protocols like AAVE and Uniswap
7. StrategyFactory - factory, that and deploys ERC1967Proxy of Strategy as isolated smart contract with liquidity
8. IntentsNFT - intents for grind, that reads data from PoolsNFT
9. GRAI - ERC20 token, that tokenize grinds on intent
10. GrinderAI - gateway for AI agent to interact with PoolsNFT and GRAI 


# PoolsNFT

`PoolsNFT` is a gateway that facilitates the creation of strategy pools and links represented by NFTs. It supports royalty mechanisms up on strategy profits, isolated deposits, limited withdrawals, and strategy iterations,

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
The `owner` has the highest level of authority in the contract and is responsible for administrative operations and configuration.

### Agent Role
The `agent` acts as a delegate for the pool owner, authorized to perform configuration of strategy params in `URUS` and rebalancing strategy pools owned by `ownerOf`.

### Depositor Role
The pools are isolated. The `depositor` is an account approved by the pool owner to contribute assets to a specific pool via `poolId`. This role ensures controlled access to deposits while allowing flexibility for liquidity contributions.

## Royalty Price Parameters
- `royaltyPriceInitNumerator`: Determines the initial royalty price as a percentage of the deposited quote token.
- `royaltyPriceCompensationShareNumerator`: Share of the royalty price allocated as compensation to the previous owner.
- `royaltyPriceReserveShareNumerator`: Share allocated to the reserve.
- `royaltyPricePoolOwnerShareNumerator`: Share allocated to the pool owner.
- `royaltyPriceGrinderShareNumerator`: Share allocated to the last grinder.

## grethShare Parameters
- `grethGrinderShareNumerator`: Share of the grinder reward allocated to the grinder (e.g., 80%).
- `grethReserveShareNumerator`: Share allocated to the reserve (e.g., 10%).
- `grethPoolOwnerShareNumerator`: Share allocated to the pool owner (e.g., 5%).
- `grethRoyaltyReceiverShareNumerator`: Share allocated to the royalty receiver (e.g., 5%).

## Royalty Parameters
- `royaltyNumerator`: Total royalty share of the profits (e.g., 20%).
- `poolOwnerShareNumerator`: Share of profits allocated to the pool owner (e.g., 80%).
- `royaltyReceiverShareNumerator`: Share of the royalty allocated to the royalty receiver. (e.g., 10%)
- `royaltyReserveShareNumerator`: Share allocated to the reserve on GRETH (e.g., 5%). 
- `royaltyOwnerShareNumerator`: Share allocated to the owner of protocol. (e.g., 5%)

## Parameter Changes
### Owner-only functions:
- `setPoolsNFTLens(address _poolsNFTLens)`: set PoolsNFTLens address
- `setGrinderAI(address _grinderAI)`: set GrinderAI address
- `setMinDeposit(address token, uint256 _minDeposit)`: set minimal deposit
- `setMaxDeposit(address token, uint256 _maxDeposit)`: set maximal deposit
- `setRoyaltyPriceInitNumerator(uint16 _royaltyPriceInitNumerator)`: set royalty price init numerator
- `setRoyaltyPriceShares(...)`: Adjust royalty price shares.
- `setGRETHShares(...)`: Adjust GRETH share distributions.
- `setRoyaltyShares(...)`: Adjust royalty distribution shares.
- `transferOwnership(address payable newOwner)` transfer ownership to `newOwner`. Require that `newOwner` call this function with same parameter
- `setStrategyFactory(address _strategyFactory)` set strategyFactory. Under the hood it instantiate strategyFactoryId
- `setStrategyStopped(uint16 strategyId, bool _isStrategyStopped)`: stops and unstops deployment of strategy
- `execute(address target, uint256 value, bytes memory data)`: execute any transaction

## Mint Process
- Use `mint` or `mintTo` to create a new isolated strategy pool:
  1. Specify `strategyId`, `quoteToken`, `baseToken`, and initial amount of `quoteToken`.
  2. Call to StrategyFactory, that deploys ERC1967Proxy with implementation of Strategy.
  3. Mint corresponding NFT bounded to deployed ERC1967Proxy.
  4. Quote Token transfers from msg.sender to PoolsNFT
  5. Call `deposit` on `Strategy` as gateway

## Deposit Process
- Deposits `quoteToken` to strategy pool with `poolId`
  1. Checks that msg.sender is depositor of `poolId`
  2. Check that `quoteTokenAmount` is in bounds of minDeposit < quoteTokenAmount < maxDeposit
  3. Quote Token transfers from msg.sender to PoolsNFT
  4. Call `deposit` on `Strategy` as gateway

## Deposit2 Process
- Deposits `baseToken` with specified `baseTokenPrice` to strategy pool with `poolId`
  1. Checks that msg.sender is depositor of `poolId`
  2. `baseToken` transfers from msg.sender to PoolsNFT
  3. Call `deposit2` on `Strategy` as gateway

## Deposit3 Process
- Deposits `quoteToken` to strategy pool with `poolId` when pool has sufficient unrealized loss
  1. Checks that msg.sender is depositor of `poolId`
  2. `quoteToken` transfers from msg.sender to PoolsNFT
  3. Call `deposit3` on `Strategy` as gateway

## Withdraw Process
- Withdraw `quoteToken` from strategy pool with `poolId`
  1. Checks that msg.sender is owner of `poolId`
  2. Call `withdraw` on `Strategy` as gateway

## Exit Process
- Withdraw all liquidity of `quoteToken` and `baseToken` from strategy pool with `poolId`
  1. Checks that msg.sender is owner of `poolId`
  2. Call `exit` on `Strategy` as gateway

## Set agent Process
- Sets agent of msg.sender

## Rebalance of Pools Process
- Rebalance of funds of two different strategy pools `poolId0` and `poolId1` with portions `rebalance0` + `rebalance0`
  1. Checks that owners of `poolId0` and `poolId1` are equal
  2. Checks that msg.sender is agent of `poolId0` and `poolId1`. Owner of pool can be agent
  3. Call `beforeRebalance` on pools with `poolId0` and `poolId1`
  4. PoolsNFT receives `baseToken` from `poolId0` and `poolId1`
  5. Rebalance funds
  6. PoolsNFT approve transfer of `baseToken`
  7. Call `afterRebalance` on pools with `poolId0` and `poolId1`

## Grind Process
- Grind strategy with `poolId`
  1. Checks that `poolId` has sufficient balance of `quoteToken` + `baseToken`
  2. Call `iterate` on `Strategy`
  3. If call was successful, than grinder earn grETH, which equal to spent tx fee

## Buy Royalty Process
- Buy royalty of `poolId`. 
  1. Calculate royalty shares
  2. msg.sender pay for royalty
  3. PoolsNFT distibute shares
  4. msg.sender become royalty receiver of `poolId`


# URUS

`URUS` is the core logic of the URUS trading algorithm implemented as a Solidity smart contract. It is designed to handle automated trading, hedging, and rebalancing strategies.

## Key Features
- Position Management: Supports long and hedge positions with configurable parameters.
- Profits Accountability: Tracks and distributes yield and trade profits for quoteToken and baseToken.
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
The `feeToken` is a utility token used to pay transaction fees during URUS operations. For most EVM chains fee token equals to WETH (wrapped ETH)

---

## 3. Quote Token
The `quoteToken` is the primary unit of account and settlement for trades. It is used to:
- Define the value of other tokens.
- Record liquidity and calculate profitability in terms of `quoteToken`

---

## 4. Base Token
The `baseToken` is the asset being traded within the URUS strategy. For example, in an ETH/USDT trading pair:
- `baseToken`: ETH
- `quoteToken`: USDT

---

## 5.1 FeeConfig

The `FeeConfig` structure in the `URUS` contract defines parameters for calculating fees applied during trading operations. Unlike a fixed percentage, the fee coefficients (`feeCoef`) are multipliers applied to the sum of **transaction fees**, allowing dynamic scaling of fees for different operations.

Definition:
```solidity
struct FeeConfig {
    uint256 longSellFeeCoef;   // Fee coeficient for selling in a long position.
    uint256 hedgeSellFeeCoef;  // Fee coeficient for selling in a hedge position.
    uint256 hedgeRebuyFeeCoef; // Fee coeficient for rebuying during a hedge operation.
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

The `Config` structure in the `URUS` contract defines critical parameters for the operation of the URUS algorithm. These parameters control the behavior of positions, thresholds, and profit margins during trading. Adjusting these values allows authorized roles to optimize the strategy for specific market conditions.

## Structure of Config

The `Config` structure contains the following parameters:

### 1. `longNumberMax`
- **Description**: The maximum number of buys, that can be executed
- **Purpose**: Limits the exposure to long positions, ensuring controlled investment levels.
- **Example**:
  - If `longNumberMax = 4`, a maximum of 4 sequential buys, that can be executed
  - **Scenario**: Assume the following conditions:
    - Initial investment: 100 USDT
    - `extraCoef = 2_00` (x2.00)
    - Long Number Max: 4
    - The investments would be:
      1)  Buy amount on iteration 1: 100 USDT 
          Total investment: 100 USDT
      2)  Buy amount on iteration 2: 100 * 2.00 = 200 USDT
          Total investment: 100 + 200 = 300 USDT
      3)  Buy amount on iteration 3: 300 * 2.00 = 600 USDT
          Total investment: 300 + 600 = 900 USDT
      4)  Buy amount on iteration 4: 900 * 2.00 = 1800 USDT
          Total investment: 900 + 1800 = 2700 USDT

### 2. `hedgeNumberMax`
- **Description**: The maximum number of hedge level grid
- **Purpose**: Defines the depth level of hedging during adverse market movements.
- **Example**:
  - If `hedgeNumberMax = 3`, the hedge process will stop after 3 iterations.
  - **Scenario**:
    - Total `baseToken` holdings: 16 units
    - Hedge process splits positions:
      1)  Hedge 1: 4 units
          Total sold: 4 units
      2)  Hedge 2: 4 units
          Total sold: 4 + 4 = 8 units
      3)  Hedge 3: 8 units
          Total sold: 8 + 8 = 16 units
    - No further hedging will occur after 3 steps. The position is closed.

### 3. `extraCoef`
- **Description**: Multiplier used to calculate the additional liquidity required for subsequent long positions.
- **Purpose**: Ensures exponential growth of investments in long positions while maintaining proportional risk.

### 4. `priceVolatilityPercent`
- **Description**: The allowed price volatility percentage for position thresholds.
- **Purpose**: Helps define the acceptable range of price movements before triggering operations.
- **Example**:
  - If `priceVolatilityPercent = 1_00` (1%):
    - Long position threshold: If price drops by 1%, a buy order is triggered.
    - **Scenario**:
      - `baseToken` price: 1000 `quoteToken`/`baseToken`
      - Volatility: 1%
      - Trigger price: 990 `quoteToken`/`baseToken`

### 5. `returnPercentLongSell`
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

Changes to the `Config` structure can only be made by authorized roles, defined in `Strategy`

- `setConfig(Config memory conf)`: sets the entire configuration.
- `setLongNumberMax(uint8 longNumberMax)`: sets the maximum number of long positions.
- `setHedgeNumberMax(uint8 hedgeNumberMax)`: sets the maximum number of levels of hedge positions.
- `setExtraCoef(uint256 extraCoef)`: sets the multiplier for liquidity calculations.
- `setPriceVolatilityPercent(uint256 priceVolatilityPercent)`: sets the allowed price volatility.
- `setOpReturnPercent(uint8 op, uint256 returnPercent)`: sets the return percentage for specific operations.


## 6. Long Position
The `long` position tracks data related to buying and holding `baseToken`:
- **`number`**: Current long buys count.
- **`numberMax`**: Maximum allowed long buys.
- **`priceMin`**: Minimum allowable threshold price for `baseToken` purchases.
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

## 8. How Deposit Works
- **Action**: Deposit `quoteToken` into the strategy pool.
- **Steps**:
  1. instantiate start timestamp
  2. `quoteToken` is transferred from the gateway
  3. make invest (caclulate initialLiquidity)
  4. put `quoteToken` to lending protocol

## 9. How Deposit2 Works
- **Action**: Deposit `baseToken` with specified `baseTokenPrice` into the strategy pool.
- **Steps**:
  1. Check that long position is not bought or used all liquidity
  2. Check that liquidity is not hedged
  3. `baseToken` is transferred from the gateway
  4. put `baseToken` to lending protocol
  5. recalculate all position related params

## 10. How Deposit3 Works
- **Action**: Deposit `quoteToken` into the strategy pool.
- **Steps**:
  1. Check that long position used all liquidity
  2. Check that liquidity is not hedged
  3. `quoteToken` is transferred from the gateway
  4. swap `quoteToken` to `baseToken`
  5. make invest (recaclulate initialLiquidity)
  4. put `baseToken` to lending protocol
  5. recalculate all position related params

---

## 11. How Withdraw Works
- **Action**: Withdraw `quoteToken` from the pool.
- **Steps**:
  1. Checks that no liquidity is used
  2. Take `quoteTokenAmount`
  3. transfer `quoteTokenAmount` to withdrawer

---

## 12. How Exit Works
- **Action**: Exit all positions and withdraw all assets.
- **Steps**:
  1. Fetches all `baseToken` and `quoteToken` from lending protocols or fund storage.
  2. Transfers tokens to the owner's address.
  3. Resets `long` and `hedge` positions to their initial state.

---

## 13. How `long_buy` Works
- **Action**: Executes a buy operation for `baseToken` in a long position.
- **Steps**:
  1. Calculates the amount of `quoteToken` required.
  2. Fetches `quoteToken` from lending protocols.
  3. Swaps `quoteToken` for `baseToken` on a DEX.
  4. Updates the long position with the new `baseToken` quantity and average price.

---

## 14. How `long_sell` Works
- **Action**: Sells all `baseToken` from a long position.
- **Steps**:
  1. Fetches all `baseToken` from lending protocols.
  2. Swaps `baseToken` for `quoteToken`.
  3. Verifies profitability based on thresholds.
  4. Distributes profits and resets the long position.

---

## 15. How `hedge_sell` Works
- **Action**: Sells `baseToken` to hedge against price declines.
- **Steps**:
  1. Calculates the `baseToken` quantity to sell.
  2. Fetches `baseToken` from lending protocols.
  3. Swaps `baseToken` for `quoteToken` on a DEX.
  4. Updates the hedge position and adjusts the long position.

---

## 14. How `hedge_rebuy` Works
- **Action**: Rebuys `baseToken` during a hedge position.
- **Steps**:
  1. Uses `quoteToken` liquidity from the hedge position.
  2. Swaps `quoteToken` for `baseToken` on a DEX.
  3. Updates the long position with the re-bought quantity.
  4. Resets the hedge position.

---

## 15. How `iterate` Works
- **Action**: Executes the appropriate trading operation based on the current state.
- **Steps**:
  1. Calls `long_buy` if no positions exist.
  2. Calls `long_sell` or `long_buy` if a long position is active.
  3. Calls `hedge_sell` or `hedge_rebuy` if hedging is active.
  4. Emits events for each operation.

---

## 16. How `beforeRebalance` and `afterRebalance` Works
### `beforeRebalance`:
- **Action**: Prepares the strategy for rebalancing.
- **Steps**:
  1. Fetches all `baseToken` from lending protocols.
  2. Transfers tokens to the rebalancing contract (gateway).
  3. Adjusts the long position accordingly.

### `afterRebalance`:
- **Action**: Updates the strategy after rebalancing.
- **Steps**:
  1. Fetches rebalanced `baseToken` from the rebalancing contract.
  2. Updates the long position with the new price and quantity.

---

# grETH

The **grETH** token is the incentivization token within the GrindURUS protocol. It rewards users (referred to as "grinders") for executing strategy iterations and serves as a mechanism to align incentives between participants and the protocol. The token is ERC-20 compliant and integrates seamlessly with the GrindURUS Pools NFT.

### **Share Calculation**
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token).
- Formula: `(Liquidity * grETH Amount) / Total grETH Supply`

All ETH trasfers to grETH are converted to WETH.

# Registry

The **Registry** contract acts as a centralized hub for managing strategy configurations, token pairs, and their associated oracles within the GrindURUS protocol. It ensures seamless integration and consistency across all strategies and token interactions.

### Key Functionalities
1. **Strategy Management**: Maintains a registry of strategy IDs and their metadata.
2. **Token Pairing**: Links quote tokens and base tokens to specific strategies.
3. **Oracle Integration**: Associates token pairs with their respective price oracles for accurate pricing data.

### Usage Examples
#### Adding a Strategy
```solidity
registry.addStrategyInfo(666, address(0x1337), "Strategy666");
```

#### Altering a Strategy
```solidity
registry.altStrategyInfo(666, address(0x69), "Strategy777");
```

#### Removing a Strategy
```solidity
registry.removeStrategyInfo(666);
```

#### Adding a GRAI Info
```solidity
registry.addGRAIInfo(666, address(0x1337), "GrinderAI token on Arbitrum");
```

#### Altering a GRAI Info
```solidity
registry.altStrategyInfo(666, address(0x69), "GrinderAI token on Arbitrum One");
```

#### Removing a GRAI Info
```solidity
registry.removeGRAIInfo(666);
```

#### Registering an Oracle
```solidity
registry.setOracle(quoteTokenAddress, baseTokenAddress, oracleAddress);
```

#### Unregistering an Oracle
```solidity
registry.unsetOracle(quoteTokenAddress, baseTokenAddress, oracleAddress);
```


#### Associating a Token Pair with a Strategy
```solidity
registry.setStrategyPair(1, quoteTokenAddress, baseTokenAddress, true);
```

#### Querying an Oracle for a Token Pair
```solidity
address oracle = registry.getOracle(quoteTokenAddress, baseTokenAddress);
```

This implementation ensures flexibility and scalability for managing strategies and token interactions within the protocol.

# Build

Initialize firstly .env
```shell
$ cp .env.example .env
```

```shell
$ forge build --sizes
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