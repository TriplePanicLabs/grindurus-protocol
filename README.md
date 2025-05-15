# GrindURUS Protocol 🚀

Automated Market Taker Protocol 🤖

Onchain yield harvesting and strategy trade protocol. 📈

## Use Cases (whole protocol) 🌟
1. **Automated Onchain Trading**: Implements a fully automated trading strategy based on mathematical and market-driven rules by one button "GRIND". 📊
2. **Capital Optimization**: Maximizes efficiency of liquidity by dynamically adjusting liquidity. 💰

## Architecture TLDR: 🏗️

Architecture:
1. **PoolsNFT** 🎴 - Enumerates all strategy pools. The gateway to the standardized interaction with strategy pools.
2. **PoolsNFTLens** 🔍 - Lens contract that retrieves data from PoolsNFT and Strategies.
3. **URUS** ⚙️ - Implements all URUS algorithm logic. Core of liquidity micromanagement
4. **Registry** 📚 - Storage of quote tokens, base tokens, and oracles, grAI crosschain info.
5. **GRETH** 🪙 - ERC20 token that stands as incentivization for `grind` and implements the index of collected profit.
6. **Strategy** 📈 - Logic that utilizes URUS + interaction with onchain protocols like AAVE and Uniswap.
7. **StrategyFactory** 🏭 - Factory that deploys ERC1967Proxy of Strategy as isolated smart contract with liquidity.
8. **GRAI** 🪙 - ERC20 token that tokenizes grinds on intent.
9. **GrinderAI** 🤖 - Gateway for AI agent to interact with PoolsNFT and GRAI.

# PoolsNFT 🎴

`PoolsNFT` is a gateway that facilitates the creation of strategy pools and links represented by NFTs. It supports royalty mechanisms upon strategy profits, deposits, withdrawals, and strategy grinding.

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
  1. Checks that `msg.sender` is agent of `poolId` ✅
  2. `baseToken` transfers from `msg.sender` to `PoolsNFT` 🔄
  3. Call `deposit2` on `Strategy` as gateway 🔑

## Withdraw Process 🏧
- Withdraw `quoteToken` from strategy pool with `poolId` 💵
  1. Checks that `msg.sender` is agent of `poolId` ✅
  2. Call `withdraw` on `Strategy` as gateway 🔑

## Exit Process 🚪
- Withdraw all liquidity of `quoteToken` and `baseToken` from strategy pool with `poolId` 💸
  1. Checks that `msg.sender` is agent of `poolId` ✅
  2. Call `exit` on `Strategy` as gateway 🔑

## Set Agent Process 🤝
- Sets agent of `poolId` 🛠️

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
    2. 🔄 Call `grind` on `Strategy`.
    3. 🏅 If the call is successful, the grinder earns `grETH`, equal to the spent transaction fee.

  ## Buy Royalty Process 💎
  - **Buy royalty** of `poolId`:
    1. 📊 Calculate royalty shares.
    2. 💰 `msg.sender` pays for the royalty.
    3. 📤 `PoolsNFT` distributes shares.
    4. 👑 `msg.sender` becomes the royalty receiver of `poolId`.

# URUS ⚙️

  `URUS` is the core logic of the URUS trading algorithm. It is designed to handle automated trading, hedging, and rebalancing liqudity from `quoteToken` to `baseToken` and vise versa.

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

## 15. How `grind` Works 🔁
- **Action**: Executes the appropriate trading operation based on the current state. ⚙️
- **Steps**:
  1. 🛒 Calls `long_buy` if no positions exist.
  2. 🔄 Calls `long_sell` or `long_buy` if a long position is active.
  3. 🛡️ Calls `hedge_sell` or `hedge_rebuy` if hedging is active.

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

**grETH** is the yield index token, representing profits accumulated in strategy pools.

### **Share Calculation** 📊
- The `share` function calculates the proportional value of a specified amount of grETH in terms of a chosen asset (native or ERC-20 token). 🔄
- **Formula**: `(Liquidity * grETH Amount) / Total grETH Supply` 🧮

All ETH transfers to grETH are converted to WETH. 🌐

---
# 📚 Registry Contract

The `Registry` contract is the metadata and configuration hub for the **GrindURUS** protocol. It maintains mappings between quote/base tokens, price oracles, strategy factories, and GRAI token configurations across chains. It also tracks token coherence for analytical and routing purposes.

## 🧠 Core Responsibilities

- Stores oracle connections between token pairs.
- Tracks all available quote and base tokens.
- Registers strategies and LayerZero endpoint information for GRAI tokens.
- Computes token coherence (used for assessing oracle coverage).
- Delegates ownership rights dynamically to the `PoolsNFT` contract's owner.

---

## ⚙️ Function Reference

### 🔐 Ownership & Access
- `owner()` → Returns the current protocol owner via `PoolsNFT`.
- `_onlyOwner()` → Reverts if caller is not owner.

### 🧩 Configuration
- `setPoolsNFT(address _poolsNFT)`  
  Set the reference address for the `PoolsNFT` contract.

- `setOracle(address quoteToken, address baseToken, address oracle)`  
  Set an oracle for a token pair and automatically deploy the inverse oracle.

- `unsetOracle(address quoteToken, address baseToken, address oracle)`  
  Remove an existing oracle mapping and clean up coherence tracking.

- `setStrategyInfo(uint16 strategyId, address factory, string description)`  
  Register a strategy with its factory and metadata.

- `setGRAIInfo(uint32 endpointId, address grai, string description)`  
  Register a GRAI token for a specific LayerZero endpoint.

## 🧮 Token Coherence

**Token Coherence** is a metric used in the `Registry` contract to quantify how well-connected a token is within the oracle graph of the GrindURUS protocol.

Each token is either a **quote token** or **base token** in an oracle pair. A token's *coherence* is defined as:

coherence(token) = number of oracle connections (excluding self-pairs)

For example, if token `A` has oracles with `B`, `C`, and `D`, then:
coherence(A) = 3 (assuming A ≠ B, C, D)

---

### 🔍 View Functions

#### 📈 Oracle Management
- `getOracle(address quoteToken, address baseToken)`  
  Get oracle for a given token pair. Returns `PriceOracleSelf` if `quote == base`.

- `hasOracle(address quoteToken, address baseToken)`  
  Returns `true` if oracle exists between the given pair.

#### 🪙 Token Lists
- `getQuoteTokens()`  
  Returns the list of all known quote tokens.

- `getBaseTokens()`  
  Returns the list of all known base tokens.

- `getQuoteTokensBy(uint256[] quoteTokenIds)`  
  Returns selected quote tokens by index.

- `getBaseTokensBy(uint256[] baseTokenIds)`  
  Returns selected base tokens by index.

#### 🧠 Strategy Info
- `getStrategyInfosBy(uint16[] strategyIds)`  
  Batch query for `StrategyInfo` by IDs.

- `getGRAIInfosBy(uint32[] endpointIds)`  
  Batch query for `GRAIInfo` by endpoint IDs.


---

# GRAI 🪙

`GRAI` is the utility token of the GrindURUS protocol, burned when a grind is executed via `GrinderAI`. It is implemented as an Omnichain Fungible Token (OFT) using LayerZero and supports cross-chain usage.

## GrinderAI-only Functions 🤖

- `setMultiplierNumerator(uint256)` — Sets the multiplier for LayerZero fee estimation.
- `setNativeBridgeFee(uint256)` — Sets additional LayerZero bridge fee percentage.
- `setPeer(uint32, bytes32)` — Registers peer endpoint for cross-chain messaging.
- `mint(address, uint256)` — Mints GRAI tokens when grinds are purchased.

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

`GrinderAI` is the autonomous agent contract for the **GrindURUS** protocol. It enables gas-efficient, transparent automation of grind operations on strategy pools using the `grAI` utility token. It supports minting, payment processing, GRAI token management, and simulation of operations on pools.

## 🛠 Configuration Functions

- `setRatePerGRAI(token, rate)` — Set price per `grAI` for a token.

## 🌐 grAI Cross-Chain Configuration Support

- `setLzReceivOptions(endpointId, gasLimit, value)` — Set LayerZero options.
- `setMultiplierNumerator(n)` — Adjust gas multiplier for fees.
- `setArtificialFeeNumerator(endpointId, n)` — Set additional bridge fee.
- `setPeer(eid, peer)` — Set remote peer for OFT sync.

## 💸 grAI Minting

- `mint(token, amount)` — Mint `grAI` to sender.
- `mintTo(token, to, amount)` — Mint `grAI` to another user.
- ETH or tokens are accepted depending on `ratePerGRAI`.

## ⚙️ Grinding

- `grind(poolId)` — Executes macro+micro grind on a pool.
- `grindOp(poolId, op)` — Executes a specific operation (`buy`, `sell`, etc).
- `batchGrind(poolIds[])` — Batch of grind pools.
- `batchGrindOp(poolIds[], ops[])` — Batch of granular grind ops.
- `microOp(poolId, op)` / `macroOp(poolId, op)` — Simulate operations.

## 🔍 View Functions

- `calcPayment(token, amount)` — Get payment needed to mint `grAI`.
- `getIntentOf(account)` — Return how many grinds the user has and pool ownership.
- `isPaymentToken(token)` — Check if token is valid for payment.
- `owner()` — Get dynamic owner (forwarded from `PoolsNFT`).

## 📥 ETH Handling

When ETH is received: all ETH go to owner


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


# 📜 License

[BUSL-1.1](https://spdx.org/licenses/BUSL-1.1.html)