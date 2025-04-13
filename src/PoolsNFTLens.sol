// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT, IURUS} from "src/interfaces/IPoolsNFT.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IPoolsNFTLens} from "src/interfaces/IPoolsNFTLens.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";

contract PoolsNFTLens is IPoolsNFTLens {
    using Base64 for bytes;
    using Strings for uint256;

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

    /// @notice base URI for this collection
    string public baseURI;

    constructor (address _poolsNFT) {
        baseURI = "https://raw.githubusercontent.com/TriplePanicLabs/grindurus-poolsnft-data/refs/heads/main/arbitrum/";
        poolsNFT = IPoolsNFT(_poolsNFT);
    }

    function owner() public view returns (address) {
        try poolsNFT.owner() returns(address payable _owner){
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) external override {
        _onlyOwner();
        baseURI = _baseURI;
    }

    function tokenURI(uint256 poolId) public view returns (string memory uri) {
        // https://raw.githubusercontent.com/TriplePanicLabs/GrindURUS-PoolsNFTsData/refs/heads/main/arbitrum/{poolId}.json
        string memory path = string.concat(baseURI, poolId.toString());
        uri = string.concat(path, ".json");
    }

    /// @notice get pool nft info by pool ids
    /// @param poolIds array of poolIds
    function getPoolNFTInfosBy(uint256[] memory poolIds) external view override returns (PoolNFTInfo[] memory poolInfos) {
        uint256 poolIdsLen = poolIds.length;
        poolInfos = new PoolNFTInfo[](poolIdsLen);
        uint256 index = 0;
        for (; index < poolIdsLen; ) {
            poolInfos[index] = _formPoolInfo(poolIds[index]);
            unchecked {
                ++index;
            }
        }
    }

    /// @notice returns positions of strategy
    /// @param poolId pool id of pool in array `pools` on PoolsNFT
    function getPositions(uint256 poolId) public view override returns(Positions memory positions) {
        IStrategy strategy = IStrategy(poolsNFT.pools(poolId));
        uint8 number;
        uint8 numberMax;
        uint256 priceMin;
        uint256 liquidity;
        uint256 qty;
        uint256 price;
        uint256 feeQty;
        uint256 feePrice; 
        (
            number,
            numberMax,
            priceMin,
            liquidity,
            qty,
            price,
            feeQty,
            feePrice
        ) = strategy.getLong();
        positions.long = IURUS.Position({
            number: number,
            numberMax: numberMax,
            priceMin: priceMin,
            liquidity: liquidity,
            qty: qty,
            price: price,
            feeQty: feeQty,
            feePrice: feePrice
        });
        (
            number,
            numberMax,
            priceMin,
            liquidity,
            qty,
            price,
            feeQty,
            feePrice
        ) = strategy.getHedge();
        positions.hedge = IURUS.Position({
            number: number,
            numberMax: numberMax,
            priceMin: priceMin,
            liquidity: liquidity,
            qty: qty,
            price: price,
            feeQty: feeQty,
            feePrice: feePrice
        });
    }

    /// @notice forms config structure for `getPoolNFTInfosBy`
    /// @param poolId id of pool
    function getConfig(uint256 poolId) public view returns (IURUS.Config memory) {
        (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 extraCoef,
            uint256 priceVolatilityPercent,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) = IStrategy(poolsNFT.pools(poolId)).getConfig();
        return IURUS.Config({
            longNumberMax: longNumberMax,
            hedgeNumberMax: hedgeNumberMax,
            extraCoef: extraCoef,
            priceVolatilityPercent: priceVolatilityPercent,
            returnPercentLongSell: returnPercentLongSell,
            returnPercentHedgeSell: returnPercentHedgeSell,
            returnPercentHedgeRebuy: returnPercentHedgeRebuy
        });
    }

    /// @notice forms fee config structure for `getPoolNFTInfosBy`
    function getFeeConfig(uint256 poolId) public view returns (IURUS.FeeConfig memory) {
        (
            uint256 longSellFeeCoef,
            uint256 hedgeSellFeeCoef,
            uint256 hedgeRebuyFeeCoef
        ) = IStrategy(poolsNFT.pools(poolId)).getFeeConfig();
        return IURUS.FeeConfig({
            longSellFeeCoef: longSellFeeCoef,
            hedgeSellFeeCoef: hedgeSellFeeCoef,
            hedgeRebuyFeeCoef: hedgeRebuyFeeCoef
        });
    }

    /// @notice returns batch of positions of strategy
    /// @param poolIds array of poolId`s on PoolsNFT
    function getPositionsBy(uint256[] memory poolIds) external view override returns (Positions[] memory positions) {
        uint256 poolIdsLen = poolIds.length;
        positions = new Positions[](poolIdsLen);
        uint256 index = 0;
        for (; index < poolIdsLen; ) {
            positions[index] = getPositions(poolIds[index]);
            unchecked {
                ++index;
            }
        }
    }

    /// @notice returns ROI structure
    /// @param poolId pool id of pool in array `pools` on PoolsNFT
    function getROI(uint256 poolId) public view returns (ROI memory) {
        IStrategy pool = IStrategy(poolsNFT.pools(poolId));
        (
            uint256 ROINumerator,
            uint256 ROIDenominator,
            uint256 ROIPeriod
        ) = pool.ROI();
        return ROI({
            ROINumerator: ROINumerator,
            ROIDeniminator: ROIDenominator,
            ROIPeriod: ROIPeriod
        });
    }

    /// @notice get thresholds of pool with `poolId`
    /// @param poolId pool id of pool in array `pools` on PoolsNFT
    function getThresholds(uint256 poolId) public view override returns (Thresholds memory) {
        (
            uint256 longBuyPriceMin,
            uint256 longSellQuoteTokenAmountThreshold,
            uint256 longSellSwapPriceThreshold,
            uint256 hedgeSellInitPriceThresholdHigh,
            uint256 hedgeSellInitPriceThresholdLow,
            uint256 hedgeSellLiquidity,
            uint256 hedgeSellQuoteTokenAmountThreshold,
            uint256 hedgeSellTargetPrice,
            uint256 hedgeSellSwapPriceThreshold,
            uint256 hedgeRebuyBaseTokenAmountThreshold,
            uint256 hedgeRebuySwapPriceThreshold
        ) = IStrategy(poolsNFT.pools(poolId)).getThresholds();

        return Thresholds({
            longBuyPriceMin: longBuyPriceMin,
            longSellQuoteTokenAmountThreshold: longSellQuoteTokenAmountThreshold,
            longSellSwapPriceThreshold: longSellSwapPriceThreshold,
            hedgeSellInitPriceThresholdHigh: hedgeSellInitPriceThresholdHigh,
            hedgeSellInitPriceThresholdLow: hedgeSellInitPriceThresholdLow,
            hedgeSellLiquidity: hedgeSellLiquidity,
            hedgeSellQuoteTokenAmountThreshold: hedgeSellQuoteTokenAmountThreshold,
            hedgeSellTargetPrice: hedgeSellTargetPrice,
            hedgeSellSwapPriceThreshold: hedgeSellSwapPriceThreshold,
            hedgeRebuyBaseTokenAmountThreshold: hedgeRebuyBaseTokenAmountThreshold,
            hedgeRebuySwapPriceThreshold: hedgeRebuySwapPriceThreshold
        });
    }

    function getRoyaltyParams(uint256 poolId) public view returns (RoyaltyParams memory) {
        (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 reserveShare,
            uint256 ownerShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        ) = poolsNFT.calcRoyaltyPriceShares(poolId);
        return RoyaltyParams({
            compensationShare: compensationShare,
            poolOwnerShare: poolOwnerShare,
            reserveShare: reserveShare,
            ownerShare: ownerShare,
            oldRoyaltyPrice: oldRoyaltyPrice,
            newRoyaltyPrice: newRoyaltyPrice
        });
    }

    /// @notice forms pool info
    /// @param poolId pool id of pool in array `pools` on PoolsNFT
    function _formPoolInfo(uint256 poolId) private view returns (PoolNFTInfo memory poolInfo) {
        IStrategy pool = IStrategy(poolsNFT.pools(poolId));
        (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        ) = pool.getProfits();
        (
            uint256 totalQuoteTokenYieldProfit,
            uint256 totalBaseTokenYieldProfit,
            uint256 totalQuoteTokenTradeProfit,
            uint256 totalBaseTokenTradeProfit
        ) = pool.getTotalProfits();
        poolInfo = PoolNFTInfo({
            poolId: poolId,
            strategyId: pool.strategyId(),
            pool: address(pool),
            positions: getPositions(poolId),
            config: getConfig(poolId),
            feeConfig: getFeeConfig(poolId),
            oracleQuoteTokenPerFeeToken: address(pool.oracleQuoteTokenPerFeeToken()),
            oracleQuoteTokenPerBaseToken: address(pool.oracleQuoteTokenPerBaseToken()),
            feeToken: address(pool.feeToken()),
            quoteToken: address(pool.getQuoteToken()),
            baseToken: address(pool.getBaseToken()),
            feeTokenSymbol: pool.feeToken().symbol(),
            quoteTokenSymbol: pool.getQuoteToken().symbol(),
            baseTokenSymbol: pool.getBaseToken().symbol(),
            oracleQuoteTokenPerFeeTokenDecimals: AggregatorV3Interface(address(pool.oracleQuoteTokenPerFeeToken())).decimals(),
            oracleQuoteTokenPerBaseTokenDecimals: AggregatorV3Interface(address(pool.oracleQuoteTokenPerBaseToken())).decimals(),
            quoteTokenDecimals: pool.getQuoteToken().decimals(),
            baseTokenDecimals: pool.getBaseToken().decimals(),
            quoteTokenAmount: pool.getQuoteTokenAmount(),
            baseTokenAmount: pool.getBaseTokenAmount(),
            activeCapital: pool.getActiveCapital(),
            startTimestamp: pool.startTimestamp(),
            profits: IURUS.Profits({
                quoteTokenYieldProfit: quoteTokenYieldProfit,
                baseTokenYieldProfit: baseTokenYieldProfit,
                quoteTokenTradeProfit: quoteTokenTradeProfit,
                baseTokenTradeProfit: baseTokenTradeProfit
            }),
            totalProfits: IURUS.Profits({
                quoteTokenYieldProfit: totalQuoteTokenYieldProfit,
                baseTokenYieldProfit: totalBaseTokenYieldProfit,
                quoteTokenTradeProfit: totalQuoteTokenTradeProfit,
                baseTokenTradeProfit: totalBaseTokenTradeProfit
            }),
            roi: getROI(poolId),
            thresholds: getThresholds(poolId),
            royaltyParams: getRoyaltyParams(poolId)
        });
    }

    /// @notice execute any transaction
    function execute(address target, uint256 value, bytes calldata data) public override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }

}