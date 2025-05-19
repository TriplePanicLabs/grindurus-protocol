// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IERC721 } from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol"; // NFT
import { IERC2981 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol"; // royalty
import { IURUS } from "src/interfaces/IURUS.sol";
import { IPoolsNFTLens } from "src/interfaces/IPoolsNFTLens.sol";
import { IGRETH } from "src/interfaces/IGRETH.sol";
import { IGrinderAI } from "src/interfaces/IGrinderAI.sol";

interface IPoolsNFT is IERC721, IERC2981 {
    
    error NotOwner();
    error NotAgent();
    error NoCapital();
    error NotMicroOp();
    error InvalidShares();
    error InvalidRoyaltyPriceInit();
    error StrategyStopped();
    error HasAgent();

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

    event Deposit2(
        uint256 poolId,
        address pool,
        address baseToken,
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    );

    event Withdraw(
        uint256 poolId,
        address to,
        address quoteToken,
        uint256 quoteTokenAmount
    );

    event Withdraw2(
        uint256 poolId,
        address to,
        address baseToken,
        uint256 baseTokenAmount
    );

    event Exit(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );

    event GrindOp(
        uint256 poolId,
        uint8 op,
        address grinder,
        bool isGrinded
    );

    event BuyRoyalty(uint256 poolId, address buyer, uint256 paidPrice);

    struct RoyaltyPriceShares {
        uint16 auctionStartShare;
        uint16 compensationShare;
        uint16 reserveShare;
        uint16 poolOwnerShare;
        uint16 ownerShare;
    }

    struct Shares {
        uint16 poolOwnerShare;
        uint16 poolBuyerShare;
        uint16 reserveShare;
        uint16 grinderShare;
    }

    //// ADDRESSES

    function pendingOwner() external view returns (address payable);

    function owner() external view returns (address payable);

    function poolsNFTLens() external view returns (IPoolsNFTLens);

    function grETH() external view returns (IGRETH);

    function grinderAI() external view returns (IGrinderAI);

    //// 

    function isStrategyStopped(uint16 stratrgyId) external view returns (bool);

    function totalPools() external view returns (uint256);

    function strategyFactory(uint16 strategyId) external view returns (address);

    function royaltyReceiver(uint256 poolId) external view returns (address);

    function royaltyPrice(uint256 poolId) external view returns (uint256);

    function agentOf(uint256 poolId) external view returns (address); 

    function pools(uint256 poolId) external view returns (address);

    function poolIds(address pool) external view returns (uint256);

    function init(address _poolsNFTLens, address _grETH, address _grinderAI) external;

    //// OWNER FUNCTIONS

    function setStrategyStopped(uint16 strategyId, bool _isStrategyStopped) external;

    function setStrategyFactory(address _strategyFactory) external;

    function setPoolsNFTLens(address _poolsNFTLens) external;

    function setRoyaltyPriceShares(RoyaltyPriceShares memory _royaltyPriceShares) external;

    function setGRETHShares(Shares memory _grethShares) external;

    function setRoyaltyShares(Shares memory _royaltyShares) external;

    function transferOwnership(address payable _owner) external;

    function mint(
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount,
        IURUS.Config memory config
    ) external returns (uint256 poolId);

    function mintTo(
        address to,
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount,
        IURUS.Config memory config
    ) external returns (uint256 poolId);

    function setAgentOf(uint256 poolId, address agent) external;

    function deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external returns (uint256 depositedQuoteTokenAmount);

    function deposit2(
        uint256 poolId,
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) external returns (uint256 depositedBaseTokenAmount);

    function withdraw(
        uint256 poolId,
        address to,
        uint256 quoteTokenAmount
    ) external returns (uint256 withdrawnQuoteTokenAmount);

    function withdraw2(
        uint256 poolId,
        address to,
        uint256 baseTokenAmount
    ) external returns (uint256 withdrawnBaseTokenAmount);

    function exit(
        uint256 poolId
    ) external returns (uint256 quoteTokenAmount, uint256 baseTokenAmount);

    function microOps(uint256 poolId) external returns (bool isGrinded);

    function microOp(uint256 poolId, uint8 op) external returns (bool isGrinded);

    function buyRoyalty(
        uint256 poolId
    ) external returns (uint256 royaltyPricePaid);

    function buyRoyaltyTo(
        uint256 poolId,
        address to
    ) external returns (uint256 royaltyPricePaid);

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
        uint256 grethReward
    ) external view returns (address[] memory actors, uint256[] memory shares);

    function baseURI() external view returns (string memory);

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function getZeroConfig() external view returns (IURUS.Config memory);

    function getRoyaltyReceiver(
        uint256 poolId
    ) external view returns (address receiver);

    function isAgentOf(uint256 poolId, address account) external view returns (bool);

    function getPoolIdsOf(
        address poolOwner
    ) external view
        returns (
            uint256[] memory poolIdsOwnedByPoolOwner
        );

    function getPoolInfosBy(
        uint256[] memory _poolIds
    ) external view returns (IPoolsNFTLens.PoolInfo[] memory poolInfos);

    function getPositionsBy(uint256[] memory _poolIds) external view returns (IPoolsNFTLens.Positions[] memory);

    function getRoyaltyPriceShares() external view returns (RoyaltyPriceShares memory);

    function getGRETHShares() external view returns (Shares memory);

    function getRoyaltyShares() external view returns (Shares memory);

    function weth() external view returns (address);

    function execute(address target, uint256 value, bytes memory data) external payable returns (bool success, bytes memory result);

}
