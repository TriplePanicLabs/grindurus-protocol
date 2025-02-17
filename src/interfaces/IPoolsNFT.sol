// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IGRETH} from "src/interfaces/IGRETH.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol"; // NFT
import {IERC2981} from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol"; // royalty
import {IURUS} from "src/interfaces/IURUS.sol";

interface IPoolsNFT is IERC721, IERC2981 {
    error NotOwner();
    error NotOwnerOrPending();
    error NotOwnerOf();
    error NotStrategiest();
    error NotDepositor();
    error NotAgent();
    error InvalidOp();
    error InvalidRoyaltyNumerator();
    error InvalidGRETHShares();
    error InvalidRoyaltyShares();
    error InvalidRoyaltyPriceShare();
    error StrategyStopped();
    error InsufficientDeposit();
    error ExceededDeposit();
    error ExceededDepositCap();
    error DifferentOwnersOfPools();
    error DifferentQuoteTokens();
    error DifferentBaseTokens();
    error ZeroNewRoyaltyPrice();
    error InsufficientRoyaltyPrice();

    event SetStrategiest(address strategiest, bool isStrategiest);
    event SetBaseURI(string baseURI);
    event SetPoolsNFTImage(address poolsNFTImage);
    event SetMinDeposit(address token, uint256 minDeposit);
    event SetTokenCap(address token, uint256 _tokenCap);
    event SetRoyaltyPriceShares(
        uint16 _royaltyPriceCompensationShareNumerator,
        uint16 _royaltyPriceReserveShareNumerator,
        uint16 _royaltyPricePoolOwnerShareNumerator,
        uint16 _royaltyPriceGrinderShareNumerator
    );
    event SetGRETHShares(
        uint16 _grethGrinderShareNumerator,
        uint16 _grethReserveShareNumerator,
        uint16 _grethPoolOwnerShareNumerator,
        uint16 _grethRoyaltyReceiverShareNumerator
    );
    event SetRoyaltyShares(
        uint16 _poolOwnerRoyaltyShareNumerator,
        uint16 _royaltyReceiverShareNumerator,
        uint16 _royaltyReserveShareNumerator,
        uint16 _royaltyGrinderShareNumerator
    );
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
    event Rebalance(uint256 poolId0, uint256 poolId1);

    event Grind(
        uint256 poolId,
        address grinder,
        bool isGrinded
    );

    event BuyRoyalty(uint256 poolId, address buyer, uint256 paidPrice);

    struct PoolNFTInfo {
        uint256 poolId;
        IURUS.Config config;
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

    //// ROYALTY PRICE SHARES

    function royaltyPriceCompensationShareNumerator() external view returns (uint16);

    function royaltyPriceReserveShareNumerator() external view returns (uint16);
    
    function royaltyPricePoolOwnerShareNumerator() external view returns (uint16);

    function royaltyPriceGrinderShareNumerator() external view returns (uint16);

    //// GRETH SHARES

    function grethGrinderShareNumerator() external view returns (uint16);

    function grethReserveShareNumerator() external view returns (uint16);

    function grethPoolOwnerShareNumerator() external view returns (uint16);

    function grethRoyaltyReceiverShareNumerator() external view returns (uint16);

    //// ROYALTY SHARES

    function royaltyNumerator() external view returns (uint16);

    function poolOwnerShareNumerator() external view returns (uint16);

    function royaltyReceiverShareNumerator() external view returns (uint16);

    function royaltyReserveShareNumerator() external view returns (uint16);

    function royaltyGrinderShareNumerator() external view returns (uint16);

    function pendingOwner() external view returns (address payable);

    function owner() external view returns (address payable);

    function lastGrinder() external view returns (address payable);

    function isStrategyStopped(uint16 stratrgyId) external view returns (bool);

    function baseURI() external view returns (string memory);

    function totalPools() external view returns (uint256);

    function grETH() external view returns (IGRETH);

    function isStrategiest(address strategiest) external view returns (bool);

    function strategyFactory(uint16 strategyId) external view returns (address);

    function royaltyReceiver(uint256 poolId) external view returns (address);

    function royaltyPrice(uint256 poolId) external view returns (uint256);

    function minter(uint256 poolId) external view returns (address); 

    function pools(uint256 poolId) external view returns (address);

    function poolIds(address pool) external view returns (uint256);

    function deposited(uint256 poolId, address token) external view returns (uint256);

    function totalDeposited(address token) external view returns (uint256);

    function minDeposit(address token) external view returns (uint256);

    function tokenCap(address token) external view returns (uint256);

    function init(address _grETH) external;

    //// ONLY STRATEGIEST FUNCTIONS
    
    function setStrategyStopped(uint16 strategyId, bool _isStrategyStopped) external;

    function setStrategyFactory(address _strategyFactory) external;

    //// ONLY OWNER FUNCTIONS

    function setStrategiest(address strategiest, bool _isStrategiest) external;

    function setMinDeposit(address token, uint256 _minDeposit) external;

    function setTokenCap(address token, uint256 _tokenCap) external;

    function setBaseURI(string memory _baseURI) external;

    function setPoolsNFTImage(address _poolsNFTImage) external;

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

    function transferOwnership(address payable _owner) external;

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

    function setRoyaltyPrice(uint256 poolId, uint256 _royaltyPrice) external;

    function setDepositor(uint256 poolId, address depositor, bool _depositorApproval) external;

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

    function setAgent(address _agent, bool _agentApproval) external;

    function rebalance(uint256 poolIdLeft, uint256 poolIdRight) external;

    function grind(uint256 poolId) external returns (bool isGrinded);

    function grindTo(uint256 poolId, address grinder) external returns (bool isGrinded);

    function grindOp(uint256 poolId, IURUS.Op op) external returns (bool isGrinded);

    function grindOpTo(uint256 poolId, IURUS.Op op, address grinder) external returns (bool isGrinded);

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

    function tokenURI(uint256 poolId) external view returns (string memory uri);

    function getRoyaltyReceiver(
        uint256 poolId
    ) external view returns (address receiver);
    
    function isAgentOf(address _ownerOf, address _agent) external view returns (bool);

    function isDepositorOf(uint256 poolId, address _depositor) external view returns (bool);

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

    function getPoolNFTInfosBy(uint256[] memory _poolIds) external view returns (PoolNFTInfo[] memory poolInfos);

    function getConfig(uint256 poolId) external view 
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 priceVolatility,
            uint256 initHedgeSellPercent,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        );

    function getLong(uint256 poolId) external view
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

    function getHedge(uint256 poolId) external view
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

    function getPositions(uint256 poolId) external view returns(IURUS.Position memory long, IURUS.Position memory hedge);

    function execute(address target, uint256 value, bytes memory data) external;

}
