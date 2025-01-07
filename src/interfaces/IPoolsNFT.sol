// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IGRETH} from "src/interfaces/IGRETH.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol"; // NFT
import {IERC2981} from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol"; // royalty
import {IURUSCore} from "src/interfaces/IURUSCore.sol";

interface IPoolsNFT is IERC721, IERC2981 {
    error NotOwner();
    error NotTreasury();
    error NotOwnerOrPending();
    error ExceededDepositCap();
    error NotOwnerOfPool(uint256 poolId, address ownerOf);
    error NotPendingOwner();
    error NotPrimaryReceiverRoyaltyOrPending();
    error NotPrimaryReceiverRoyalty();
    error NotPendingPrimaryReceiverRoyalty();
    error StartRoyaltyPriceNumeratorZero();
    error InvalidRoyaltyNumerator();
    error InvalidGRETHShares();
    error InvalidRoyaltyShares();
    error InvalidRoyaltyPriceShare();
    error InvalidPoolNFTInfos();
    error InvalidInitRoyaltyPriceNumerator();
    error InsufficientDeposit();
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
    error ZeroETH();
    error FailETHTransfer();
    error FailTokenTransfer(address token);

    event SetFactoryStrategy(uint256 strategyId, address factoryStrategy);
    event Mint(
        uint256 poolId,
        address baseToken,
        address quoteToken
    );
    event Deposit(
        uint256 poolId,
        address pool,
        address quoteToken,
        uint256 quoteTokenAmount
    );
    event Withdraw(
        uint256 poolId,
        address to,
        address quoteToken,
        uint256 quoteTokenAmount
    );
    event Exit(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );

    event Grind(uint256 poolId, address grinder);

    event BuyRoyalty(uint256 poolId, address buyer, uint256 paidPrice);

    event ReceiveETH(uint256 ethAmount);

    struct PoolNFTInfo {
        uint256 poolId;
        IURUSCore.Config config;
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
        uint256 activeCapital;
        /// royalty price
        uint256 royaltyPrice;
    }

    function pendingOwner() external view returns (address payable);

    function owner() external view returns (address payable);

    function lastGrinder() external view returns (address payable);

    function baseURI() external view returns (string memory);

    function totalPools() external view returns (uint256);

    function grETH() external view returns (IGRETH);

    function royaltyReceiver(uint256 poolId) external view returns (address);

    function royaltyPrice(uint256 poolId) external view returns (uint256);

    function pools(uint256 poolId) external view returns (address);

    function poolIds(address pool) external view returns (uint256);

    function deposited(uint256 poolId, address token) external view returns (uint256);

    function totalDeposited(address token) external view returns (uint256);

    function tokenCap(address token) external view returns (uint256);

    /////// ONLY OWNER FUNCTIONS
    
    function setMinimumDeposit(address token, uint256 _minimumDeposit) external;

    function setTokenCap(address token, uint256 _tokenCap) external;

    function setBaseURI(string memory _baseURI) external;

    function setPoolsNFTImage(address _poolsNFTImage) external;

    function setInitRoyaltyPriceNumerator(uint16 _initRoyaltyPriceNumerator) external;

    function setRoyaltyShares(
        uint16 _poolOwnerRoyaltyShareNumerator,
        uint16 _treasuryRoyaltyShareNumerator,
        uint16 _royaltyReceiverShareNumerator,
        uint16 _grinderRoyaltyShareNumerator
    ) external;

    function setGRETHShares(
        uint16 _grethGrinderShareNumerator,
        uint16 _grethReserveShareNumerator,
        uint16 _grethPoolOwnerShareNumerator,
        uint16 _grethRoyaltyReceiverShareNumerator
    ) external;

    function setRoyaltyPriceShares(
        uint16 _royaltyPriceCompensationShareNumerator,
        uint16 _royaltyPricePrimaryReceiverShareNumerator,
        uint16 _royaltyPricePoolOwnerShareNumerator,
        uint16 _royaltyPriceLastGrinderShareNumerator
    ) external;

    function setGRETH(address _grETH) external;

    function transferOwnership(address payable _owner) external;

    function setStrategyFactory(address _strategyFactory) external;

    function mint(
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) external returns (uint256 poolId);

    function mintTo(
        address to,
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) external returns (uint256 poolId);

    function deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external returns (uint256 deposited);

    function withdraw(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external returns (uint256 withdrawn);

    function withdrawTo(
        uint256 poolId,
        address to,
        uint256 quoteTokenAmount
    ) external returns (uint256 withdrawn);

    function exit(
        uint256 poolId
    ) external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function rebalance(uint256 poolIdLeft, uint256 poolIdRight) external;

    function grind(uint256 poolId) external;

    function buyRoyalty(
        uint256 poolId
    ) external payable returns (uint256 royaltyPricePaid, uint256 refund);

    function buyRoyaltyTo(
        uint256 poolId,
        address payable to
    ) external payable returns (uint256 royaltyPricePaid, uint256 refund);

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount);

    function calcRoyaltyShares(
        uint256 poolId,
        uint256 profit
    )
        external
        view
        returns (address[] memory receivers, uint256[] memory amounts);

    function calcRoyaltyPriceShares(
        uint256 poolId
    )
        external
        view
        returns (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 treasuryShare,
            uint256 lastGrinderShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        );

    function calcGRETHShares(
        uint256 poolId,
        uint256 grethReward,
        address grinder
    ) external view returns (address[] memory actors, uint256[] memory shares);

    function calcInitialRoyaltyPrice(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external view returns (uint256 initRoyaltyPrice);

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function getRoyaltyReceiver(
        uint256 poolId
    ) external view returns (address receiver);

    function getPoolIdsOf(
        address poolOwner
    )
        external
        view
        returns (
            uint256 totalPoolIds,
            uint256[] memory poolIdsOwnedByPoolOwner
        );

    function getPoolNFTInfos(
        uint256 fromPoolId,
        uint256 toPoolId
    ) external view returns (PoolNFTInfo[] memory poolsInfo);

    function getConfig(uint256 poolId) external view returns (IURUSCore.Config memory);

    function getLong(
        uint256 poolId
    )
        external
        view
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        );

    function getHedge(
        uint256 poolId
    )
        external
        view
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        );

    function sweep(address token, address to) external payable;
}
