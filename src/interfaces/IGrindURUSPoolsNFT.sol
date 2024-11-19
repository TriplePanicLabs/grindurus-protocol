// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol"; // NFT
import {IERC2981} from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol"; // royalty

interface IGrindURUSPoolsNFT is IERC721, IERC2981 {

    error NotOwner();
    error NotOwnerOfPool(uint256 poolId, address ownerOf);
    error NotPendingOwner();
    error NotStrategiest();
    error NotPrimaryReceiverRoyalty();
    error NotPendingPrimaryReceiverRoyalty();
    error StartRoyaltyPriceNumeratorZero();
    error RoyaltyNumeratorExceedsMaxValue();
    error InvalidRoyaltyShares();
    error InvalidRoyaltyPriceShare();
    error RoyaltyNumeratorZero();
    error StrategyDontExist();
    error NotAllowedToRebalance();
    error DifferentStrategyId();
    error DifferentBaseTokens();
    error DifferentQuoteTokens();
    error InsufficientRoyaltyPrice();
    error InsufficientBuyOwnership();
    error FailCompensationShare();
    error FailPoolOwnerShare();
    error FailPrimaryReceiverShare();
    error FailLastGrinderShare();
    error FailRefund();
    error FailBuyOwnership();

    event SetFactoryStrategy(uint256 strategyId, address factoryStrategy);
    event Mint(
        uint256 poolId, 
        address oracleQuoteTokenPerFeeToken,
        address oracleQuoteTokenPerBaseToken,
        address feeToken,
        address baseToken,
        address quoteToken
    );
    event Deposit(uint256 poolId, address pool, address quoteToken, uint256 quoteTokenAmount);
    event Withdraw(uint256 poolId, address to, address quoteToken, uint256 quoteTokenAmount);
    event Exit(uint256 poolId, uint256 quoteTokenAmount, uint256 baseTokenAmount);

    event Grind(uint256 poolId, address grinder);
    event LongBuy(uint256 poolId, uint256 quoteTokenAmount, uint256 baseTokenAmount);
    event LongSell(uint256 poolId, uint256 quoteTokenAmount, uint256 baseTokenAmount);
    event HedgeSell(uint256 poolId, uint256 quoteTokenAmount, uint256 baseTokenAmount);
    event HedgeRebuy(uint256 poolId, uint256 quoteTokenAmount, uint256 baseTokenAmount);
    event ReceiveETH(uint256 ethAmount);

    struct PoolNFTInfo {
        uint256 poolId;
        uint256 strategyId;
        address quoteToken;
        address baseToken;
        string quoteTokenSymbol;
        string baseTokenSymbol;
        uint256 quoteTokenAmount;
        uint256 baseTokenAmount;
        /// yield and trade profits
        uint256 quoteTokenYieldProfit;
        uint256 baseTokenYieldProfit;
        uint256 quoteTokenTradeProfit;
        uint256 baseTokenTradeProfit;
        /// APR
        uint256 APRNumerator;
        uint256 APRDenominator;
        /// royalty price
        uint256 royaltyPrice;
    }

    function owner() external view returns (address payable);

    function primaryReceiverRoyalty() external view returns (address payable);

    function royaltyReceiver(uint256 poolId) external view returns (address);

    function royaltyPrice(uint256 poolId) external view returns (uint256);

    function royaltyShares(uint256 poolId, uint256 profit) external view returns (
        uint8 length,
        address[] memory receivers,
        uint256[] memory amounts
    );

    function pools(uint256 poolId) external view returns (address);

    function poolIds(address pool) external view returns (uint256);

    function grind(uint256 poolId) external;

    function buyRoyalty(uint256 poolId) external payable returns (uint256 royaltyPricePaid, uint256 refund);

    function buyOwnership() external payable returns (uint256 ownershipPricePaid, uint256 refund);

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount);

    function getPoolNFTInfos(uint256 fromPoolId, uint256 toPoolId) external view returns (PoolNFTInfo[] memory poolsInfo);

    function getLong(uint256 poolId) external view returns (
        uint8 number,
        uint256 priceMin,
        uint256 liquidity,
        uint256 qty,
        uint256 price,
        uint256 feeQty,
        uint256 feePrice
    );

    function getHedge(uint256 poolId) external view returns (
        uint8 number,
        uint256 priceMin,
        uint256 liquidity,
        uint256 qty,
        uint256 price,
        uint256 feeQty,
        uint256 feePrice
    );

    function getConfig(uint256 poolId) external view returns (
        uint8 longNumberMax,
        uint8 hedgeNumberMax,
        uint256 averagePriceVolatility,
        uint256 extraCoef,
        uint256 returnPercentLongSell,
        uint256 returnPercentHedgeSell,
        uint256 returnPercentHedgeRebuy
    );


}