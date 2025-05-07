// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IURUS} from "src/interfaces/IURUS.sol";

interface IPoolsNFTLens {

    error NotOwner();

    struct Positions {
        IURUS.Position long;
        IURUS.Position hedge;
    }

    struct ROI {
        uint256 ROINumerator;
        uint256 ROIDeniminator;
        uint256 ROIPeriod;
    }

    struct Thresholds {
        uint256 spotPrice;
        uint256 longBuyPriceMin;
        uint256 longSellQuoteTokenAmountThreshold;
        uint256 longSellSwapPriceThreshold;
        uint256 hedgeSellInitPriceThresholdHigh;
        uint256 hedgeSellInitPriceThresholdLow;
        uint256 hedgeSellLiquidity;
        uint256 hedgeSellQuoteTokenAmountThreshold;
        uint256 hedgeSellTargetPrice;
        uint256 hedgeSellSwapPriceThreshold;
        uint256 hedgeRebuyBaseTokenAmountThreshold;
        uint256 hedgeRebuySwapPriceThreshold;
    }

    struct RoyaltyParams {
        uint256 compensationShare;
        uint256 poolOwnerShare;
        uint256 reserveShare;
        uint256 ownerShare;
        uint256 oldRoyaltyPrice;
        uint256 newRoyaltyPrice;
    }

    struct PoolNFTInfo {
        uint256 poolId;
        uint256 strategyId;
        address pool;
        Positions positions;
        IURUS.Config config;
        IURUS.FeeConfig feeConfig;
        address oracleQuoteTokenPerBaseToken;
        address oracleQuoteTokenPerFeeToken;
        address feeToken;
        address quoteToken;
        address baseToken;
        string feeTokenSymbol;
        string quoteTokenSymbol;
        string baseTokenSymbol;
        uint8 oracleQuoteTokenPerBaseTokenDecimals;
        uint8 oracleQuoteTokenPerFeeTokenDecimals;
        uint8 quoteTokenDecimals;
        uint8 baseTokenDecimals;
        uint256 quoteTokenAmount;
        uint256 baseTokenAmount;
        uint256 activeCapital;
        /// yield and trade profits
        uint256 startTimestamp;
        IURUS.Profits profits;
        IURUS.Profits totalProfits;
        ROI roi;
        Thresholds thresholds;
        /// royalty params
        RoyaltyParams royaltyParams;
    }

    function poolsNFT() external view returns (IPoolsNFT);

    function baseURI() external view returns (string memory);

    function setBaseURI(string memory _baseURI) external;

    function tokenURI(uint256 poolId) external view returns (string memory);

    function getPositions(uint256 poolId) external view returns(Positions memory positions);

    function getPositionsBy(uint256[] memory poolIds) external view returns(Positions[] memory positions);

    function getConfig(uint256 poolId) external view returns(IURUS.Config memory);

    function getFeeConfig(uint256 poolId) external view returns (IURUS.FeeConfig memory);

    function getThresholds(uint256 poolId) external view returns (Thresholds memory);

    function getPoolNFTInfosBy(uint256[] memory poolIds) external view returns (PoolNFTInfo[] memory poolInfos);

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bool success, bytes memory result);

}