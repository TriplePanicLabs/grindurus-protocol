# GrindURUS Protocol 🚀

Automated Market Taker 🤖

Onchain yield harvesting and strategy trade protocol. 📈

## Use Cases (whole protocol) 🌟
1. **Automated Trading**: Implements a fully automated trading strategy based on mathematical and market-driven rules. 📊
2. **Risk Management**: Uses hedging and rebuying to mitigate unrealized loss. 🛡️
3. **Capital Optimization**: Maximizes efficiency by dynamically adjusting liquidity and investment levels. 💰

## Architecture TLDR: 🏗️

Architecture:
1. **PoolsNFT** 🎴 - Enumerates all strategy pools. The gateway to the standardized interaction with strategy pools.
2. **PoolsNFTLens** 🔍 - Lens contract that retrieves data from PoolsNFT and Strategies.
3. **URUS** ⚙️ - Implements all URUS algorithm logic.
4. **Registry** 📚 - Storage of quote tokens, base tokens, and oracles.
5. **GRETH** 🪙 - ERC20 token that stands as incentivization for `grind` and implements the index of collected profit.
6. **Strategy** 📈 - Logic that utilizes URUS + interaction with onchain protocols like AAVE and Uniswap.
7. **StrategyFactory** 🏭 - Factory that deploys ERC1967Proxy of Strategy as isolated smart contract with liquidity.
8. **IntentsNFT** 🎯 - Intents for grind, that reads data from PoolsNFT.
9. **GRAI** 🪙 - ERC20 token that tokenizes grinds on intent.
10. **GrinderAI** 🤖 - Gateway for AI agent to interact with PoolsNFT and GRAI.

# PoolsNFT 🎴

`PoolsNFT` is a gateway that facilitates the creation of strategy pools and links represented by NFTs. It supports royalty mechanisms upon strategy profits, isolated deposits, limited withdrawals, and strategy iterations.

## Key Features ✨
- **Pool Ownership**: Each NFT represents ownership of a strategy pool. 🏦
- **Royalties**: Configurable royalty system with shares for pool owners, grinders, and reserve funds on grETH token. 💎
- **Deposits & Withdrawals**: Supports token deposits and withdrawals while enforcing caps and minimum limits to trusted actors. 💳
- **Profit Sharing**: Distributes profits between participants of the strategy pool. 📤📥
- **Rebalancing**: Enables efficient pool balancing across different strategies. ⚖️
- **Royalty Trading**: Allows users to buy royalty on strategy profits. 🛒

## Core Functionalities 🛠️
- **Minting**: Deploys a strategy pool and mints its NFT representation. 🖨️
- **Grind Mechanism**: Rewards users with grETH for maintaining pool strategies. 🏅
- **Management**: Flexible configuration of deposits, royalty shares, and pool limits. 🔧
## Roles 🛡️
### Owner Role 👑
The `owner` has the highest level of authority in the contract and is responsible for administrative operations and configuration. 🛠️

### Agent Role 🤝
The `agent` acts as a delegate for the pool owner, authorized to perform configuration of strategy parameters in `URUS` and rebalancing strategy pools owned by `ownerOf`. 🔄

### Depositor Role 💳
The pools are isolated. The `depositor` is an account approved by the pool owner to contribute assets to a specific pool via `poolId`. This role ensures controlled access to deposits while allowing flexibility for liquidity contributions. 💧

## Royalty Price Parameters 💎
- **`royaltyPriceInitNumerator`**: Determines the initial royalty price as a percentage of the deposited quote token. 📊
- **`royaltyPriceCompensationShareNumerator`**: Share of the royalty price allocated as compensation to the previous owner. 💰
- **`royaltyPriceReserveShareNumerator`**: Share allocated to the reserve. 🏦
- **`royaltyPricePoolOwnerShareNumerator`**: Share allocated to the pool owner. 🏠
- **`royaltyPriceGrinderShareNumerator`**: Share allocated to the last grinder. 🏅

## grethShare Parameters 🪙
- **`grethGrinderShareNumerator`**: Share of the grinder reward allocated to the grinder (e.g., 80%). 🏆
- **`grethReserveShareNumerator`**: Share allocated to the reserve (e.g., 10%). 🏦
- **`grethPoolOwnerShareNumerator`**: Share allocated to the pool owner (e.g., 5%). 🏠
- **`grethRoyaltyReceiverShareNumerator`**: Share allocated to the royalty receiver (e.g., 5%). 💎

## Royalty Parameters 💰
- **`royaltyNumerator`**: Total royalty share of the profits (e.g., 20%). 📈
- **`poolOwnerShareNumerator`**: Share of profits allocated to the pool owner (e.g., 80%). 🏠
- **`royaltyReceiverShareNumerator`**: Share of the royalty allocated to the royalty receiver (e.g., 10%). 💎
- **`royaltyReserveShareNumerator`**: Share allocated to the reserve on GRETH (e.g., 5%). 🏦
- **`royaltyOwnerShareNumerator`**: Share allocated to the owner of the protocol (e.g., 5%). 👑

## Parameter Changes 🛠️
### Owner-only functions 👑
- `setPoolsNFTLens(address _poolsNFTLens)` 🖼️: Set the PoolsNFTLens address.
- `setGrinderAI(address _grinderAI)` 🤖: Set the GrinderAI address.
- `setMinDeposit(address token, uint256 _minDeposit)` 💳: Set the minimal deposit amount.
- `setMaxDeposit(address token, uint256 _maxDeposit)` 💰: Set the maximal deposit amount.
- `setRoyaltyPriceInitNumerator(uint16 _royaltyPriceInitNumerator)` 💎: Set the royalty price initial numerator.
- `setRoyaltyPriceShares(...)` 📊: Adjust royalty price shares.
- `setGRETHShares(...)` 🪙: Adjust GRETH share distributions.
- `setRoyaltyShares(...)` 💎: Adjust royalty distribution shares.
- `transferOwnership(address payable newOwner)` 🔄: Transfer ownership to `newOwner`. Requires `newOwner` to call this function with the same parameter.
- `setStrategyFactory(address _strategyFactory)` 🏭: Set the strategy factory. Internally instantiates `strategyFactoryId`.
- `setStrategyStopped(uint16 strategyId, bool _isStrategyStopped)` ⛔: Stop or resume the deployment of a strategy.
- `execute(address target, uint256 value, bytes memory data)` 🚀: Execute any transaction.

## Mint Process 🖨️
- Use `mint` or `mintTo` to create a new isolated strategy pool:
  1. Specify `strategyId`, `quoteToken`, `baseToken`, and the initial amount of `quoteToken`. 🪙
  2. Call the `StrategyFactory`, which deploys an ERC1967Proxy with the implementation of `Strategy`. 🏗️
  3. Mint the corresponding NFT bound to the deployed ERC1967Proxy. 🎴
  4. Transfer `quoteToken` from `msg.sender` to `PoolsNFT`. 💳
  5. Call `deposit` on `Strategy` as a gateway. 🔑

## Deposit Process 💳
- Deposit `quoteToken` to a strategy pool with `poolId`:
  1. Check that `msg.sender` is the depositor of `poolId`. 🛡️
  2. Ensure that `quoteTokenAmount` is within the bounds of `minDeposit < quoteTokenAmount < maxDeposit`. 📏
  3. Transfer `quoteToken` from `msg.sender` to `PoolsNFT`. 💰
  4. Call `deposit` on `Strategy` as a gateway. 🔑
  
## Deposit2 Process 💳
- Deposits `baseToken` with specified `baseTokenPrice` to strategy pool with `poolId` 🏦
  1. Checks that `msg.sender` is depositor of `poolId` ✅
  2. `baseToken` transfers from `msg.sender` to `PoolsNFT` 🔄
  3. Call `deposit2` on `Strategy` as gateway 🔑

## Deposit3 Process 💰
- Deposits `quoteToken` to strategy pool with `poolId` when pool has sufficient unrealized loss 📉
  1. Checks that `msg.sender` is depositor of `poolId` ✅
  2. `quoteToken` transfers from `msg.sender` to `PoolsNFT` 🔄
  3. Call `deposit3` on `Strategy` as gateway 🔑

## Withdraw Process 🏧
- Withdraw `quoteToken` from strategy pool with `poolId` 💵
  1. Checks that `msg.sender` is owner of `poolId` ✅
  2. Call `withdraw` on `Strategy` as gateway 🔑

## Exit Process 🚪
- Withdraw all liquidity of `quoteToken` and `baseToken` from strategy pool with `poolId` 💸
  1. Checks that `msg.sender` is owner of `poolId` ✅
  2. Call `exit` on `Strategy` as gateway 🔑

## Set Agent Process 🤝
- Sets agent of `msg.sender` 🛠️

## Rebalance of Pools Process ⚖️
- Rebalance funds of two different strategy pools `poolId0` and `poolId1` with portions `rebalance0` + `rebalance1` 🔄
  1. Checks that owners of `poolId0` and `poolId1` are equal ✅
  2. Checks that `msg.sender` is agent of `poolId0` and `poolId1`. Owner of pool can be agent 🤝
  3. Call `beforeRebalance` on pools with `poolId0` and `poolId1` 🔧
  4. `PoolsNFT` receives `baseToken` from `poolId0` and `poolId1` 📥
  5. Rebalance funds ⚖️
  6. `PoolsNFT` approves transfer of `baseToken` ✅
  7. Call `afterRebalance` on pools with `poolId0` and `poolId1` 🔧
  
## Grind Process 🛠️
  - **Grind strategy** with `poolId`:
    1. ✅ Checks that `poolId` has sufficient balance of `quoteToken` + `baseToken`.
    2. 🔄 Call `iterate` on `Strategy`.
    3. 🏅 If the call is successful, the grinder earns `grETH`, equal to the spent transaction fee.

  ## Buy Royalty Process 💎
  - **Buy royalty** of `poolId`:
    1. 📊 Calculate royalty shares.
    2. 💰 `msg.sender` pays for the royalty.
    3. 📤 `PoolsNFT` distributes shares.
    4. 👑 `msg.sender` becomes the royalty receiver of `poolId`.

  # URUS ⚙️

  `URUS` is the core logic of the URUS trading algorithm implemented as a Solidity smart contract. It is designed to handle automated trading, hedging, and rebalancing strategies.

  ## Key Features ✨
  - **Position Management**: Supports long and hedge positions with configurable parameters. 📈📉
  - **Profits Accountability**: Tracks and distributes yield and trade profits for `quoteToken` and `baseToken`. 💵
  - **Investment & Rebalancing**: Handles liquidity management, token swaps, and holding through lending/liquidity protocols. 🔄

  ---

  ## 1. HelperData 🧰
  The `HelperData` struct contains metadata and dynamic parameters essential for the functionality of the URUS algorithm:
  - **Token Decimals**: Stores decimals for `baseToken`, `quoteToken`, and `feeToken`. 🔢
  - **Oracle Decimals**: Stores decimals and multipliers for price oracles. 📊
  - **Coefficient Multipliers**: Constants for fee and percentage calculations. ⚙️
  - **Dynamic Data**: Includes `initLiquidity` (initial liquidity) and `investCoef` (investment coefficient). 💡

  ---

  ## 2. Fee Token 🪙
  The `feeToken` is a utility token used to pay transaction fees during URUS operations. For most EVM chains, the fee token equals `WETH` (wrapped ETH). 🌐
 
  ## 3. Quote Token 💵
  The `quoteToken` is the primary unit of account and settlement for trades. It is used to:
  - Define the value of other tokens. 📊
  - Record liquidity and calculate profitability in terms of `quoteToken`. 💰

  ---

  ## 4. Base Token 🪙
  The `baseToken` is the asset being traded within the URUS strategy. For example, in an ETH/USDT trading pair:
  - `baseToken`: ETH 🛠️
  - `quoteToken`: USDT 💵

  ---

  ## 5.1 FeeConfig ⚙️

  The `FeeConfig` structure in the `URUS` contract defines parameters for calculating fees applied during trading operations. Unlike a fixed percentage, the fee coefficients (`feeCoef`) are multipliers applied to the sum of **transaction fees**, allowing dynamic scaling of fees for different operations. 📈

Definition:
```solidity
struct FeeConfig {
    uint256 longSellFeeCoef;   // Fee coeficient for selling in a long position.
    uint256 hedgeSellFeeCoef;  // Fee coeficient for selling in a hedge position.
    uint256 hedgeRebuyFeeCoef; // Fee coeficient for rebuying during a hedge operation.
}
```

### 1. Fee Config: `longSellFeeCoef` 💰
- **Description**: Coefficient used to calculate the fee for a `long_sell` operation. 🛒
- **Purpose**: Covers additional protocol fees for selling a long position. 🏦
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `longSellFeeCoef`. 🔄
- **Example**:
  - If `feeQty = 50` (in feeToken) and `longSellFeeCoef = 1_50`:
    \[
    \text{Total Fee} = \frac{50 \times 1.50}{100} = 75 \, \text{feeToken}.
    \] 🧮

### 2. Fee Config: `hedgeSellFeeCoef` 📉
- **Description**: Coefficient used to calculate the fee for a `hedge_sell` operation. 🔧
- **Purpose**: Ensures coverage of costs and rewards for selling during a hedge position. 🛡️
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `hedgeSellFeeCoef`. 🔄
- **Example**:
  - If `feeQty = 30` (in feeToken) and `hedgeSellFeeCoef = 2_00`:
    \[
    \text{Total Fee} = \frac{30 \times 2.00}{100} = 60 \, \text{feeToken}.
    \] 🧮

### 3. Fee Config: `hedgeRebuyFeeCoef` 🔄
- **Description**: Coefficient used to calculate the fee for a `hedge_rebuy` operation. 💵
- **Purpose**: Covers costs associated with rebuying assets during a hedge position. 🛠️
- **How It Works**:
  - Multiplies the base transaction fee (`feeQty`) by `hedgeRebuyFeeCoef`. 🔄
- **Example**:
  - If `feeQty = 40` (in feeToken) and `hedgeRebuyFeeCoef = 1_75`:
    \[
    \text{Total Fee} = \frac{40 \times 1.75}{100} = 70 \, \text{feeToken}.
    \] 🧮

### Fee Calculation Process 🧾

Fees are calculated as follows:
1. Determine the **transaction fee** (`feeQty`) in `feeToken`. This can include:
   - Gas costs in `feeToken`. ⛽
   - Additional operational expenses. ⚙️
2. Apply the corresponding fee coefficient (`feeCoef`): 🔢
   \[
   \text{Total Fee} = \frac{\text{feeQty} \times \text{feeCoef}}{\text{helper.coefMultiplier}}
   \] 🧮
  ## 5.2 Config ⚙️

  The `Config` structure in the `URUS` contract defines critical parameters for the operation of the URUS algorithm. These parameters control the behavior of positions, thresholds, and profit margins during trading. Adjusting these values allows authorized roles to optimize the strategy for specific market conditions. 📊

  ## Structure of Config 🏗️

  The `Config` structure contains the following parameters:

  ### 1. `longNumberMax` 🔢
  - **Description**: The maximum number of buys that can be executed. 🛒
  - **Purpose**: Limits the exposure to long positions, ensuring controlled investment levels. 🛡️
  - **Example**:
    - If `longNumberMax = 4`, a maximum of 4 sequential buys can be executed. 🔄
    - **Scenario**: Assume the following conditions:
      - Initial investment: 100 USDT 💵
      - `extraCoef = 2_00` (x2.00) 🔧
      - Long Number Max: 4 🔢
      - The investments would be:
        1)  Buy amount on iteration 1: 100 USDT 💰  
            Total investment: 100 USDT 💵
        2)  Buy amount on iteration 2: 100 * 2.00 = 200 USDT 💰  
            Total investment: 100 + 200 = 300 USDT 💵
        3)  Buy amount on iteration 3: 300 * 2.00 = 600 USDT 💰  
            Total investment: 300 + 600 = 900 USDT 💵
        4)  Buy amount on iteration 4: 900 * 2.00 = 1800 USDT 💰  
            Total investment: 900 + 1800 = 2700 USDT 💵

  ### 2. `hedgeNumberMax` 🛡️
  - **Description**: The maximum number of hedge level grids. 📉
  - **Purpose**: Defines the depth level of hedging during adverse market movements. ⚖️
  - **Example**:
    - If `hedgeNumberMax = 3`, the hedge process will stop after 3 iterations. ⛔
    - **Scenario**:
      - Total `baseToken` holdings: 16 units 🪙
      - Hedge process splits positions:
        1)  Hedge 1: 4 units 🛒  
            Total sold: 4 units 📤
        2)  Hedge 2: 4 units 🛒  
            Total sold: 4 + 4 = 8 units 📤
        3)  Hedge 3: 8 units 🛒  
            Total sold: 8 + 8 = 16 units 📤
      - No further hedging will occur after 3 steps. The position is closed. 🚪

  ### 3. `extraCoef` 🔄
  - **Description**: Multiplier used to calculate the additional liquidity required for subsequent long positions. 📈
  - **Purpose**: Ensures exponential growth of investments in long positions while maintaining proportional risk. ⚙️
  ### 4. `priceVolatilityPercent` 🌊
  - **Description**: The allowed price volatility percentage for position thresholds. 📉📈
  - **Purpose**: Helps define the acceptable range of price movements before triggering operations. 🎯
  - **Example**:
    - If `priceVolatilityPercent = 1_00` (1%): 📊
      - Long position threshold: If price drops by 1%, a buy order is triggered. 🛒
      - **Scenario**:
        - `baseToken` price: 1000 `quoteToken`/`baseToken` 💵
        - Volatility: 1% 🌪️
        - Trigger price: 990 `quoteToken`/`baseToken` 🔔

  ### 5. `returnPercentLongSell` 💰
  - **Description**: The required return percentage to execute a profitable `long_sell`. 📈
  - **Purpose**: Ensures that long positions are sold only when a certain profit margin is achieved. 🏦
  - **Example**:
    - If `returnPercentLongSell = 100_50` (100.5%): 📊
      - A `long_sell` will only execute if the return is 0.5% or more above the initial investment. 🛍️
      - **Scenario**:
        - Initial investment: $1,000 💵
        - Required return: $1,005 (0.5% profit) 🏆

  ### 7. `returnPercentHedgeSell` 🛡️
  - **Description**: The required return percentage to execute a profitable `hedge_sell`. 📉
  - **Purpose**: Protects hedge positions by ensuring a minimum profit margin before selling. ⚖️
  - **Example**:
    - If `returnPercentHedgeSell = 100_50` (100.5%): 📊
      - A `hedge_sell` will only execute if the return is 0.5% or more above the investment. 🛒

  ### 8. `returnPercentHedgeRebuy` 🔄
  - **Description**: The required return percentage to execute a profitable `hedge_rebuy`. 💵
  - **Purpose**: Ensures that hedge positions are repurchased only when a certain profit margin is achievable. 🏦
  - **Example**:
    - If `returnPercentHedgeRebuy = 100_50` (100.5%): 📊
      - A `hedge_rebuy` will only execute if the return is 0.5% or more. 🛍️

## Adjusting Config 🛠️

Changes to the `Config` structure can only be made by authorized roles, defined in `Strategy`:

- **`setConfig(Config memory conf)`** 🛠️: Sets the entire configuration.
- **`setLongNumberMax(uint8 longNumberMax)`** 🔢: Sets the maximum number of long positions.
- **`setHedgeNumberMax(uint8 hedgeNumberMax)`** 🛡️: Sets the maximum number of levels of hedge positions.
- **`setExtraCoef(uint256 extraCoef)`** 🔄: Sets the multiplier for liquidity calculations.
- **`setPriceVolatilityPercent(uint256 priceVolatilityPercent)`** 🌊: Sets the allowed price volatility.
- **`setOpReturnPercent(uint8 op, uint256 returnPercent)`** 📈: Sets the return percentage for specific operations.

---

## 6. Long Position 📈

The `long` position tracks data related to buying and holding `baseToken`:

- **`number`** 🔢: Current long buys count.
- **`numberMax`** 🚀: Maximum allowed long buys.
- **`priceMin`** 📉: Minimum allowable threshold price for `baseToken` purchases.
- **`liquidity`** 💰: Quote token liquidity in the position.
- **`qty`** 🪙: Quantity of `baseToken` held.
- **`price`** ⚖️: Weighted average cost price.
- **`feeQty`** 💵: Total fee quantity accrued in `feeToken`.
- **`feePrice`** 📊: Fee price in terms of `quoteToken`.

---

## 7. Hedge Position 🛡️

The `hedge` position tracks data for hedging against price declines:

- **`number`** 🔢: Current hedge position count.
- **`numberMax`** 🛑: Maximum allowed hedge positions.
- **`priceMin`** 📉: Minimum price at which the hedge was initialized.
- **`liquidity`** 💰: Quote token liquidity used in the hedge.
- **`qty`** 🪙: Quantity of `baseToken` hedged.
- **`price`** ⚖️: Hedge price.
- **`feeQty`** 💵: Total fee quantity accrued in `feeToken`.
- **`feePrice`** 📊: Fee price in terms of `quoteToken`.

---

## 8. How Deposit Works 💳

- **Action**: Deposit `quoteToken` into the strategy pool.
- **Steps**:
  1. 🕒 Instantiate start timestamp.
  2. 💰 `quoteToken` is transferred from the gateway.
  3. 🔄 Make an investment (calculate `initialLiquidity`).
  4. 🏦 Put `quoteToken` into the lending protocol.

---

## 9. How Deposit2 Works 💳

- **Action**: Deposit `baseToken` with specified `baseTokenPrice` into the strategy pool.
- **Steps**:
  1. ✅ Check that the long position is not bought or has used all liquidity.
  2. ✅ Check that liquidity is not hedged.
  3. 💰 `baseToken` is transferred from the gateway.
  4. 🏦 Put `baseToken` into the lending protocol.
  5. 🔄 Recalculate all position-related parameters.
  
## 10. How Deposit3 Works 💳
- **Action**: Deposit `quoteToken` into the strategy pool. 🏦
- **Steps**:
1. ✅ Check that the long position used all liquidity.
2. 🛡️ Check that liquidity is not hedged.
3. 💰 `quoteToken` is transferred from the gateway.
4. 🔄 Swap `quoteToken` to `baseToken`.
5. 🏗️ Make an investment (recalculate `initialLiquidity`).
6. 🏦 Put `baseToken` into the lending protocol.
7. 📊 Recalculate all position-related parameters.

---

## 11. How Withdraw Works 🏧
- **Action**: Withdraw `quoteToken` from the pool. 💵
- **Steps**:
1. ✅ Check that no liquidity is used.
2. 💰 Take `quoteTokenAmount`.
3. 📤 Transfer `quoteTokenAmount` to the withdrawer.

---

## 12. How Exit Works 🚪
- **Action**: Exit all positions and withdraw all assets. 💸
- **Steps**:
1. 🏦 Fetch all `baseToken` and `quoteToken` from lending protocols or fund storage.
2. 📤 Transfer tokens to the owner's address.
3. 🔄 Reset `long` and `hedge` positions to their initial state.

---

## 13. How `long_buy` Works 🛒
- **Action**: Executes a buy operation for `baseToken` in a long position. 📈
- **Steps**:
1. 🧮 Calculate the amount of `quoteToken` required.
2. 💰 Fetch `quoteToken` from lending protocols.
3. 🔄 Swap `quoteToken` for `baseToken` on a DEX.
4. 📊 Update the long position with the new `baseToken` quantity and average price.

---

## 14. How `long_sell` Works 🛍️
- **Action**: Sells all `baseToken` from a long position. 📉
- **Steps**:
1. 🏦 Fetch all `baseToken` from lending protocols.
2. 🔄 Swap `baseToken` for `quoteToken`.
3. ✅ Verify profitability based on thresholds.
4. 💵 Distribute profits and reset the long position.
---

## 15. How `hedge_sell` Works 🛡️
- **Action**: Sells `baseToken` to hedge against price declines. 📉
- **Steps**:
  1. 🧮 Calculates the `baseToken` quantity to sell.
  2. 🏦 Fetches `baseToken` from lending protocols.
  3. 🔄 Swaps `baseToken` for `quoteToken` on a DEX.
  4. 📊 Updates the hedge position and adjusts the long position.

---

## 14. How `hedge_rebuy` Works 🔄
- **Action**: Rebuys `baseToken` during a hedge position. 📈
- **Steps**:
  1. 💰 Uses `quoteToken` liquidity from the hedge position.
  2. 🔄 Swaps `quoteToken` for `baseToken` on a DEX.
  3. 📊 Updates the long position with the re-bought quantity.
  4. 🛠️ Resets the hedge position.

---

## 15. How `iterate` Works 🔁
- **Action**: Executes the appropriate trading operation based on the current state. ⚙️
- **Steps**:
  1. 🛒 Calls `long_buy` if no positions exist.
  2. 🔄 Calls `long_sell` or `long_buy` if a long position is active.
  3. 🛡️ Calls `hedge_sell` or `hedge_rebuy` if hedging is active.
  4. 📢 Emits events for each operation.

---

## 16. How `beforeRebalance` and `afterRebalance` Works ⚖️
### `beforeRebalance`:
- **Action**: Prepares the strategy for rebalancing. 🛠️
- **Steps**:
  1. 🏦 Fetches all `baseToken` from lending protocols.
  2. 🔄 Transfers tokens to the rebalancing contract (gateway).
  3. 📊 Adjusts the long position accordingly.

### `afterRebalance`:
- **Action**: Updates the strategy after rebalancing. 🔧
- **Steps**:
  1. 🏦 Fetches rebalanced `baseToken` from the rebalancing contract.
  2. 📊 Updates the long position with the new price and quantity.

---

# grETH 🪙

The **grETH** token is the incentivization token within the GrindURUS protocol. It rewards users (referred to as "grinders") for executing strategy iterations and serves as a mechanism to align incentives between participants and the protocol. The token is ERC-20 compliant and integrates seamlessly with the GrindURUS Pools NFT. 🎴

### **Share Calculation** 📊
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token). 🔄
- **Formula**: `(Liquidity * grETH Amount) / Total grETH Supply` 🧮

All ETH transfers to grETH are converted to WETH. 🌐

---

# Registry 📚

The **Registry** contract acts as a centralized hub for managing strategy configurations, token pairs, and their associated oracles within the GrindURUS protocol. It ensures seamless integration and consistency across all strategies and token interactions. 🔗

### Key Functionalities ✨
1. **Strategy Management**: Maintains a registry of strategy IDs and their metadata. 🏗️
2. **Token Pairing**: Links quote tokens and base tokens to specific strategies. 💱
3. **Oracle Integration**: Associates token pairs with their respective price oracles for accurate pricing data. 📈

### Usage Examples 🛠️
#### Adding a Strategy ➕
```solidity
registry.addStrategyInfo(666, address(0x1337), "Strategy666");
```

#### Altering a Strategy ✏️
```solidity
registry.altStrategyInfo(666, address(0x69), "Strategy777");
```

#### Removing a Strategy ❌
```solidity
registry.removeStrategyInfo(666);
```

#### Adding a GRAI Info ➕
```solidity
registry.addGRAIInfo(666, address(0x1337), "GrinderAI token on Arbitrum");
```

#### Altering a GRAI Info ✏️
```solidity
registry.altStrategyInfo(666, address(0x69), "GrinderAI token on Arbitrum One");
```

#### Removing a GRAI Info ❌
```solidity
registry.removeGRAIInfo(666);
```

#### Registering an Oracle 🛠️
```solidity
registry.setOracle(quoteTokenAddress, baseTokenAddress, oracleAddress);
```

#### Unregistering an Oracle ❌
```solidity
registry.unsetOracle(quoteTokenAddress, baseTokenAddress, oracleAddress);
```

#### Querying an Oracle for a Token Pair 🔍
```solidity
address oracle = registry.getOracle(quoteTokenAddress, baseTokenAddress);
```

#### Querying GRAI Infos 🔍
```solidity
function getGRAIInfos() public view override returns (GRAIInfo[] memory)
```

---

# IntentsNFT 🎯

IntentsNFT is an ERC721-based contract that represents "intents" for executing operations within the GrindURUS protocol. It acts as a pseudo-soulbound token, enabling users to manage "grinds" (units of work) and interact with the protocol's strategies. 🛠️

## Intent Structure 🏗️
The `Intent` structure represents a user's intent to perform operations within the GrindURUS protocol. 📜

```solidity
struct Intent {
  address owner;       // The owner of the intent (user's address). 👤
  uint256 grinds;      // The total number of grinds (units of work) associated with the intent. 🔄
  uint256[] poolIds;   // An array of pool IDs linked to the intent. Retrieve from PoolsNFT 🎴
}
```

## Mint Intent 🖨️

The `mint` function creates a new intent for the caller (`msg.sender`) and mints an NFT representing that intent. It calculates the required payment for the specified number of grinds and processes the payment. 💰

```solidity
function mintTo(address paymentToken, address to, uint256 period) external payable returns (uint256);
```

- **`paymentToken`**: The address of the token used for payment. If `paymentToken` is `address(0)`, the payment is made in ETH. 🪙
- **`to`**: Address of the receiver of the intent. 📬
- **`_grinds`**: The number of grinds (units of work) to associate with the new intent. 🔢

### How It Works ⚙️

1. **Payment Calculation** 🧮

```solidity
function calcPayment(address paymentToken, uint256 grinds) external view returns (uint256 paymentAmount);
```

The function calculates the required payment amount using the `calcPayment` function, based on the `ratePerGrind` of `paymentToken` for the specified payment token. 📊

2. **Payment Processing** 💳  
   The payment is processed using the internal `_pay` function, which transfers the required amount to the `fundsReceiver`. 🏦

3. **Minting the Intent** 🎴  
   - If the user does not already own an intent, a new NFT is minted, and the intent is initialized with the specified number of grinds. 🆕  
   - If the user already owns an intent, the existing intent is updated with the new grinds. 🔄

# GRAI 🪙

`GRAI` is a cross-chain ERC20 token built on the LayerZero protocol. It facilitates seamless token transfers across multiple blockchains and serves as the primary token for the GrindURUS protocol. 🌐

## Parameter Changes 🛠️
### GrinderAI-only functions 🤖:
- **`setMultiplierNumerator(uint256 _multiplierNumerator)`**: Sets the multiplier numerator. On LayerZero contracts, this is used for fee estimation for cross-chain messages. Parameter `_multiplierNumerator` sets the multiplier for fee estimation. The denominator is constant at `100_00` (100%). 📊
- **`setNativeBridgeFee(uint256 _nativeBridgeFeeNumerator)`**: Sets the percentage of the native bridge fee. If the estimation is `x ETH`, the bridge fee is added to the estimated fee. 💰
- **`setPeer(uint32 eid, bytes32 _peer)`**: Sets the peer for the endpoint ID. This is LayerZero-specific functionality. 🔗
- **`mint(address to, uint256 amount)`**: Mints GRAI tokens to the specified address (`to`). 🖨️

## Bridging GRAI 🌉

`GRAI` uses LayerZero infrastructure for bridging. 🚀

### How to Bridge 🛤️

1. **Earn Estimation of Fee** 🧮
  ```solidity
  function getTotalFeesForBridgeTo(uint32 dstChainId, bytes32 toAddress, uint256 amount) external view returns (uint256 nativeFee, uint256 nativeBridgeFee, uint256 totalNativeFee);
  ```
  - This function calculates the total fees required for bridging, including native fees and bridge fees. 💵

2. **Call `bridgeTo` Function** 🔄
  Use the `bridgeTo` function with the value `totalNativeFee` obtained in step 1:
  ```solidity
  function bridgeTo(uint32 dstChainId, bytes32 toAddress, uint256 amount) external payable;
  ```

  **Parameters**:
  1. **`dstChainId`**: Defined in `graiInfos` on the `Registry`. 🌍
  2. **`toAddress`**: Encoded as a `bytes32` address of the receiver. The peer is stored as a `bytes32` to support non-EVM chains. 📬
  3. **`amount`**: The amount of GRAI to bridge. 🪙

# GrinderAI 🤖

`GrinderAI` 🤖 is a core contract in the GrindURUS protocol that acts as an AI-driven agent for managing and interacting with protocol components. It provides a transparent mechanism for automating operations such as minting tokens, managing pools, and configuring strategies. The contract integrates with PoolsNFT 🎴, IntentsNFT 🎯, and GRAI 🪙 to streamline protocol interactions.

## Parameter Changes 🛠️
### Owner-only functions 👑:
- **`setAgent(address _agent, bool _isAgent)`** 🤝: Assigns or removes an agent. Agents can configure pools and strategies.
- **`setPoolsNFT(address _poolsNFT)`** 🎴: Sets the address of the PoolsNFT contract.
- **`setIntentsNFT(address _intentsNFT)`** 🎯: Sets the address of the IntentsNFT contract.
- **`setGRAI(address _grAI)`** 🪙: Sets the address of the GRAI token contract.
- **`setGrindsRate(uint256 _grindsRate)`** 🔄: Sets the grinds rate.
- **`setGRAIReward(uint256 _graiReward)`** 🏅: Updates the reward amount of GRAI tokens for grinding operations.
- **`setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value)`** ⛽: Configures LayerZero bridge gas limits and values.
- **`setMultiplierNumerator(uint256 multiplierNumerator)`** 📊: Sets the multiplier numerator for LayerZero fee estimation. The denominator is fixed at 100_00 (100%).
- **`setNativeBridgeFee(uint256 nativeBridgeFeeNumerator)`** 💰: Sets the percentage of native bridge fees for LayerZero operations.
- **`setPeer(uint32 eid, bytes32 peer)`** 🔗: Sets the peer address for a specific endpoint ID. The peer is stored as a `bytes32` to support non-EVM chains.
- **`execute(address target, uint256 value, bytes calldata data)`** 🚀: Executes arbitrary transactions on behalf of the contract.
- **`executeGRAI(address target, uint256 value, bytes calldata data)`** 🪙: Executes arbitrary transactions on the GRAI contract.

### Delegate-only functions 🤝:
- **`setConfig(uint256 poolId, IURUS.Config memory config)`** ⚙️: Sets the configuration for a specific pool.
- **`batchSetConfig(uint256[] memory poolIds, IURUS.Config[] memory configs)`** 🔄: Sets configurations for multiple pools in a single transaction.
- **`setLongNumberMax(uint256 poolId, uint8 longNumberMax)`** 📈: Updates the `longNumberMax` parameter for a pool.
- **`setHedgeNumberMax(uint256 poolId, uint8 hedgeNumberMax)`** 🛡️: Updates the `hedgeNumberMax` parameter for a pool.
- **`setExtraCoef(uint256 poolId, uint256 extraCoef)`** 🔧: Updates the `extraCoef` parameter for a pool.
- **`setPriceVolatilityPercent(uint256 poolId, uint256 priceVolatilityPercent)`** 🌊: Updates the `priceVolatilityPercent` parameter for a pool.
- **`setOpReturnPercent(uint256 poolId, uint8 op, uint256 returnPercent)`** 📊: Updates the return percentage for a specific operation in a pool.
- **`setOpFeeCoef(uint256 poolId, uint8 op, uint256 feeCoef)`** 💵: Updates the fee coefficient for a specific operation in a pool.

### Public functions (callable by anyone) 🌐:
- **`grind(uint256 poolId)`** 🛠️: Executes a grinding operation on a specific pool and mints GRAI rewards if successful.
- **`grindOp(uint256 poolId, uint8 op)`** 🔄: Executes a specific operation (e.g., buy, sell, hedge) on a pool and mints GRAI rewards if successful.
- **`batchGrind(uint256[] memory poolIds)`** 🔁: Executes grinding operations on multiple pools.
- **`batchGrindOp(uint256[] memory poolIds, uint8[] memory ops)`** 🔄: Executes specific operations on multiple pools.

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