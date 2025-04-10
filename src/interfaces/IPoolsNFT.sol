// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IGRETH} from "src/interfaces/IGRETH.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol"; // NFT
import {IERC2981} from "lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol"; // royalty
import {IURUS} from "src/interfaces/IURUS.sol";
import {IPoolsNFTLens} from "src/interfaces/IPoolsNFTLens.sol";

interface IPoolsNFT is IERC721, IERC2981 {
    error NotOwner();
    error NotOwnerOf();
    error NotDepositor();
    error NotAgent();
    error NoCapital();
    error InvalidOp();
    error InvalidShares();
    error InvalidRoyaltyPriceInit();
    error StrategyStopped();
    error InsufficientMinDeposit();
    error ExceededMaxDeposit();
    error DifferentOwnersOfPools();
    error DifferentTokens();

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
    event Exit(
        uint256 poolId,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    );
    event Rebalance(uint256 poolId0, uint256 poolId1);

    event Grind(
        uint256 poolId,
        uint8 op,
        address grinder,
        bool isGrinded
    );

    event BuyRoyalty(uint256 poolId, address buyer, uint256 paidPrice);

    //// ROYALTY PRICE SHARES

    function royaltyPriceCompensationShareNumerator() external view returns (uint16);

    function royaltyPriceReserveShareNumerator() external view returns (uint16);
    
    function royaltyPricePoolOwnerShareNumerator() external view returns (uint16);

    function royaltyPriceOwnerShareNumerator() external view returns (uint16);

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

    function royaltyOwnerShareNumerator() external view returns (uint16);

    function pendingOwner() external view returns (address payable);

    function owner() external view returns (address payable);

    function isStrategyStopped(uint16 stratrgyId) external view returns (bool);

    function totalPools() external view returns (uint256);

    function grETH() external view returns (IGRETH);

    function strategyFactory(uint16 strategyId) external view returns (address);

    function royaltyReceiver(uint256 poolId) external view returns (address);

    function royaltyPrice(uint256 poolId) external view returns (uint256);

    function minter(uint256 poolId) external view returns (address); 

    function pools(uint256 poolId) external view returns (address);

    function poolIds(address pool) external view returns (uint256);

    function minDeposit(address token) external view returns (uint256);

    function maxDeposit(address token) external view returns (uint256);
    
    function isDisapprovedGrinderAI(address ownerOf) external view returns (bool);

    function init(address _poolsNFTLens, address _grETH, address _grinderAI) external;

    //// ONLY STRATEGIEST FUNCTIONS
    
    function setStrategyStopped(uint16 strategyId, bool _isStrategyStopped) external;

    function setStrategyFactory(address _strategyFactory) external;

    //// ONLY OWNER FUNCTIONS

    function setPoolsNFTLens(address _poolsNFTLens) external;

    function setGRETH(address _grETH) external;

    function setGrinderAI(address _grinderAI) external;

    function setMinDeposit(address token, uint256 _minDeposit) external;

    function setMaxDeposit(address token, uint256 _minDeposit) external;

    function setRoyaltyPriceInitNumerator(uint16 _royaltyPriceInitNumerator) external;

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

    function setDepositor(uint256 poolId, address depositor, bool _depositorApproval) external;

    function deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external returns (uint256 depositedQuoteTokenAmount);

    function deposit2(
        uint256 poolId,
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) external returns (uint256 depositedBaseTokenAmount);

    function deposit3(uint256 poolId, uint256 quoteTokenAmount) external;

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

    function rebalance(uint256 poolIdLeft, uint256 poolIdRight, uint8 rebalanceLeft, uint8 rebalnceRight) external;

    function grind(uint256 poolId) external returns (bool isGrinded);

    function grindTo(uint256 poolId, address grinder) external returns (bool isGrinded);

    function grindOp(uint256 poolId, uint8 op) external returns (bool isGrinded);

    function grindOpTo(uint256 poolId, uint8 op, address grinder) external returns (bool isGrinded);

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
    ) external view
        returns (
            uint256[] memory poolIdsOwnedByPoolOwner
        );

    function getPoolNFTInfosBy(
        uint256[] memory _poolIds
    ) external view returns (IPoolsNFTLens.PoolNFTInfo[] memory poolNFTInfos);

    function getPositionsBy(uint256[] memory _poolIds) external view returns (IPoolsNFTLens.Positions[] memory);

    function execute(address target, uint256 value, bytes memory data) external returns (bool success, bytes memory result);

}
