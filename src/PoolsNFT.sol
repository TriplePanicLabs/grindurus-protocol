// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IGRETH} from "src/interfaces/IGRETH.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IPoolStrategy} from "src/interfaces/IPoolStrategy.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IFactoryPoolStrategy} from "src/interfaces/IFactoryPoolStrategy.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC721, ERC721Enumerable, IERC165} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title GrindURUS Pools NFT
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice NFT that represets ownership of every grindurus strategy pools
contract PoolsNFT is
    IPoolsNFT,
    ERC721Enumerable,
    ReentrancyGuard
{
    using SafeERC20 for IToken;
    using Base64 for bytes;
    using Strings for uint256;

    //// CONTSTANTS ////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    /// @notice maximum royalty numerator.
    /// @dev this value of max royalty is 30%
    /// Dont panic, the actural royalty numerator stores in `royaltyNumerator`
    uint16 public constant MAX_ROYALTY_NUMERATOR = 30_00;

    //// ROYALTY PRICE SHARES //////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice the init royalty price numerator
    /// @dev converts initial `quoteToken` to `feeToken` and multiply to numerator and divide by DENOMINATOR
    uint16 public royaltyInitPriceNumerator;

    /// require CompensationShareNumerator + TreasuryShareNumerator + PoolOwnerShareNumerator + LastGrinderShareNumerator > 100%
    /// @dev numerator of royalty price compensation to previous owner share
    uint16 public royaltyPriceCompensationShareNumerator;

    /// @dev numerator of royalty price primary receiver share
    uint16 public royaltyPriceReserveShareNumerator;

    /// @dev numerator of royalty price pool owner share
    uint16 public royaltyPricePoolOwnerShareNumerator;

    /// @dev numerator of royalty price last grinder share
    uint16 public royaltyPriceGrinderShareNumerator;

    //// GRETH SHARES //////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev numerator of grinder share 
    /// @dev grETHGrinderShareNumerator == 80_00 == 80%
    uint16 public grethGrinderShareNumerator;

    /// @dev numerator of grETH reserve share
    /// @dev grETHReserveShareNumerator == 10_00 == 10%
    uint16 public grethReserveShareNumerator;

    /// @dev numerator of pool owner share
    /// @dev example: grETHPoolOwnerShareNumerator == 5_00 = 5%
    uint16 public grethPoolOwnerShareNumerator;

    /// @dev numerator of royalty receiver share
    /// @dev example: grETHRoyaltyReceiverShareNumerator == 5_00 = 5%
    uint16 public grethRoyaltyReceiverShareNumerator;

    //// ROYALTY SHARES ////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice the numerator of royalty
    /// @dev royaltyNumerator = DENIMINATOR - poolOwnerShareNumerator
    /// @dev example: royaltyNumerator == 20_00 == 20%
    uint16 public royaltyNumerator;

    /// @notice the numerator of pool owner share
    /// @dev poolOwnerShareNumerator = DENOMINATOR - royaltyNumerator
    /// @dev example: poolOwnerShareNumerator == 80_00 == 80%
    uint16 public poolOwnerShareNumerator;

    /// @notice royalty share of royalty receiver. You can buy it
    /// @dev example: royaltyReceiverShareNumerator == 16_00 == 16%
    uint16 public royaltyReceiverShareNumerator;

    /// @notice royalty share of reserve. Reserve on grETH
    /// @dev example: poolOwnerShareNumerator == 3_50 == 3.5%
    uint16 public royaltyReserveShareNumerator;

    /// @notice royalty share of last grinder
    /// @dev example: royaltyGrinderShareNumerator == 50 == 0.5%
    uint16 public royaltyGrinderShareNumerator;

    //// PoolsNFT OWNERSHIP DATA ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev address of pending owner
    address payable public pendingOwner;

    /// @dev address of grindurus protocol owner. For future DAO
    address payable public owner;

    /// @notice address,that last called grind()
    /// @dev address of last grinder
    /// The last of magician blyat
    address payable public lastGrinder;

    //// POOLSNFT DATA /////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice base URI for this collection
    string public baseURI;

    /// @notice total amount of pools
    uint256 public totalPools;

    /// @dev grETH token address
    IGRETH public grETH;

    /// @dev strategyId => address of grindurus pool strategy implementation
    mapping(uint16 strategyId => IFactoryPoolStrategy) public factoryStrategy;

    /// @dev poolId => royalty receiver
    mapping(uint256 poolId => address) public royaltyReceiver;

    /// @dev poolId => royalty price
    mapping(uint256 poolId => uint256) public royaltyPrice;

    /// @notice store minter of pool for airdrop points
    /// @dev poolId => address of creator of NFT
    mapping(uint256 poolId => address) public minter;

    /// @dev poolId => pool strategy address
    mapping(uint256 poolId => address) public pools;

    /// @dev pool strategy address => poolId
    mapping(address pool => uint256) public poolIds;

    /// @dev poolId => token address => deposit amount
    mapping (uint256 poolId => mapping (address token => uint256)) public deposited;

    /// @dev quoteToken => amount of deposit in pool
    mapping(address token => uint256) public totalDeposited;

    /// @dev token address => token cap
    /// @dev if cap == 0, than cap is unlimited
    mapping(address token => uint256) public tokenCap;

    constructor()
        ERC721("GRINDURUS Pools Collection", "GRINDURUS_POOLS")
    {
        baseURI = "https://raw.githubusercontent.com/TriplePanicLabs/GrindURUS-PoolsNFTsData/refs/heads/main/arbitrum/";
        totalPools = 0;
        pendingOwner = payable(address(0));
        owner = payable(msg.sender);
        lastGrinder = payable(msg.sender);

        royaltyPriceCompensationShareNumerator = 101_00; // 101%
        royaltyPriceReserveShareNumerator = 1_00; // 1%
        royaltyPricePoolOwnerShareNumerator = 5_00; // 5%
        royaltyPriceGrinderShareNumerator = 1_00; // 1%
        require(royaltyPriceCompensationShareNumerator + royaltyPriceReserveShareNumerator + royaltyPricePoolOwnerShareNumerator + royaltyPriceGrinderShareNumerator > DENOMINATOR);

        grethGrinderShareNumerator = 80_00; // 80%
        grethReserveShareNumerator = 5_00; // 5%
        grethPoolOwnerShareNumerator = 4_00; // 4%
        grethRoyaltyReceiverShareNumerator = 11_00; // 11%;
        require(grethGrinderShareNumerator + grethReserveShareNumerator + grethPoolOwnerShareNumerator + grethRoyaltyReceiverShareNumerator == DENOMINATOR);

        // total share in buy royalty = 101% + 1% + 5% + 1% = 108%
        royaltyInitPriceNumerator = 10_00; // 10%
        // poolOwnerShareNumerator + royaltyReserveShareNumerator + royaltyReceiverShareNumerator + royaltyGrinderShareNumerator == DENOMINATOR
        royaltyNumerator = 20_00; // 20%
        poolOwnerShareNumerator = 80_00; // 80%
        royaltyReceiverShareNumerator = 15_00; // 15%
        royaltyReserveShareNumerator = 4_00; // 4%
        royaltyGrinderShareNumerator = 1_00; // 1%
        require(royaltyNumerator + poolOwnerShareNumerator == DENOMINATOR);
        require(poolOwnerShareNumerator + royaltyReceiverShareNumerator + royaltyReserveShareNumerator + royaltyGrinderShareNumerator == DENOMINATOR);
        //  profit = 1 USDT
        //  profit to pool owner = 1 * (80%) = 0.8 USDT
        //  royalty = 1 * 20% = 0.2 USDT
        //      royalty to reserve  = 0.2 * 4% = 0.008 USDT
        //      royalty to royaly receiver = 0.2 * 15% = 0.03 USDT
        //      royalty grinder = 0.2 * 1% = 0.002 USDT
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    /// @notice checks that msg.sender is owner of pool id
    function _onlyOwnerOf(uint256 poolId) private view {
        address _ownerOf = ownerOf(poolId);
        if (msg.sender != _ownerOf) {
            revert NotOwnerOfPool(poolId, _ownerOf);
        }
    }

    /////// ONLY OWNER FUNCTIONS

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) external override {
        _onlyOwner();
        baseURI = _baseURI;
    }

    /// @notice sets cap tvl
    /// @dev if _capTVL==0, than no cap for asset
    /// @param token address of token
    /// @param _tokenCap maximum amount of token
    function setTokenCap(address token, uint256 _tokenCap) external override {
        _onlyOwner();
        tokenCap[token] = _tokenCap;
    }

    /// @notice sets start royalty price
    /// @dev callable only by owner
    function setInitRoyaltyPriceNumerator(
        uint16 _royaltyInitPriceNumerator
    ) external override {
        _onlyOwner();
        royaltyInitPriceNumerator = _royaltyInitPriceNumerator;
    }

    /// @notice sets royalty price share to actors
    /// @dev callable only by owner
    function setRoyaltyPriceShares(
        uint16 _royaltyPriceCompensationShareNumerator,
        uint16 _royaltyPriceReserveShareNumerator,
        uint16 _royaltyPricePoolOwnerShareNumerator,
        uint16 _royaltyPriceGrinderShareNumerator
    ) external override {
        _onlyOwner();
        if (_royaltyPriceCompensationShareNumerator <= DENOMINATOR) {
            revert InvalidRoyaltyPriceShare();
        }
        royaltyPriceCompensationShareNumerator = _royaltyPriceCompensationShareNumerator;
        royaltyPriceReserveShareNumerator = _royaltyPriceReserveShareNumerator;
        royaltyPricePoolOwnerShareNumerator = _royaltyPricePoolOwnerShareNumerator;
        royaltyPriceGrinderShareNumerator = _royaltyPriceGrinderShareNumerator;
    }

    /// @notice sets greth shares
    /// @dev callable only by owner
    function setGRETHShares(
        uint16 _grethGrinderShareNumerator,
        uint16 _grethReserveShareNumerator,
        uint16 _grethPoolOwnerShareNumerator,
        uint16 _grethRoyaltyReceiverShareNumerator
    ) external override {
        _onlyOwner();
        if (_grethGrinderShareNumerator + _grethReserveShareNumerator + _grethPoolOwnerShareNumerator + _grethRoyaltyReceiverShareNumerator != DENOMINATOR) {
            revert InvalidGRETHShares();
        }
        grethGrinderShareNumerator = _grethGrinderShareNumerator; // 80%
        grethReserveShareNumerator = _grethReserveShareNumerator; // 10%
        grethPoolOwnerShareNumerator = _grethPoolOwnerShareNumerator; // 5%
        grethRoyaltyReceiverShareNumerator = _grethRoyaltyReceiverShareNumerator; // 5%
    }

    /// @notice sets primary receiver royalty share
    /// @dev callable only by owner
    function setRoyaltyShares(
        uint16 _poolOwnerRoyaltyShareNumerator,
        uint16 _royaltyReceiverShareNumerator,
        uint16 _royaltyReserveShareNumerator,
        uint16 _royaltyGrinderShareNumerator
    ) external override {
        _onlyOwner();
        if (_poolOwnerRoyaltyShareNumerator + _royaltyReceiverShareNumerator + _royaltyReserveShareNumerator + _royaltyGrinderShareNumerator != DENOMINATOR) {
            revert InvalidRoyaltyShares();
        }
        royaltyNumerator = DENOMINATOR - _poolOwnerRoyaltyShareNumerator;
        if (royaltyNumerator > MAX_ROYALTY_NUMERATOR) {
            revert InvalidRoyaltyNumerator();
        }
        poolOwnerShareNumerator = _poolOwnerRoyaltyShareNumerator;
        royaltyReceiverShareNumerator = _royaltyReceiverShareNumerator;
        royaltyReserveShareNumerator = _royaltyReserveShareNumerator;
        royaltyGrinderShareNumerator = _royaltyGrinderShareNumerator;
    }

    /// @notice sets grETH token
    /// @dev callable only by owner
    function setGRETH(address _grETH) external override {
        _onlyOwner();
        grETH = IGRETH(_grETH);
    }

    /// @notice First step - transfering ownership to `newOwner`
    ///         Second step - accept ownership
    /// @dev for future DAO
    function transferOwnership(address payable _owner) external override {
        if (payable(msg.sender) != owner && payable(msg.sender) != pendingOwner) {
            revert NotOwnerOrPending();
        }
        if (payable(msg.sender) == owner) {
            pendingOwner = _owner;
        } else {
            owner = pendingOwner;
            pendingOwner = payable(address(0));
        }
    }

    /// @notice set factrory strategy
    /// @dev callable only by strategiest
    function setFactoryStrategy(address _factoryStrategy) external override {
        _onlyOwner();
        uint16 strategyId = IFactoryPoolStrategy(_factoryStrategy).strategyId();
        factoryStrategy[strategyId] = IFactoryPoolStrategy(_factoryStrategy);
        emit SetFactoryStrategy(strategyId, _factoryStrategy);
    }

    /////// PUBLIC FUNCTIONS

    /// @notice mints NFT with deployment of strategy
    /// @dev mints to `msg.sender`
    /// @param strategyId id of strategy implementation
    /// @param oracleQuoteTokenPerFeeToken address of oracle `quoteToken` per `feeToken` that should implement `AggregatorV3Interface`
    /// @param oracleQuoteTokenPerBaseToken address of oracle `quoteToken` per `baseToken` that should implement `AggregatorV3Interface`
    /// @param feeToken address of feeToken
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quoteToken to be deposited after mint
    function mint(
        uint16 strategyId,
        address oracleQuoteTokenPerFeeToken,
        address oracleQuoteTokenPerBaseToken,
        address feeToken,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) external override returns (uint256 poolId) {
        poolId = mintTo(
            msg.sender,
            strategyId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );
    }

    /// @notice mints NFT with deployment of strategy
    /// @dev mints to `to`
    /// @param strategyId id of strategy implementation
    /// @param oracleQuoteTokenPerFeeToken address of oracle `quoteToken` per `feeToken` that should implement `AggregatorV3Interface`
    /// @param oracleQuoteTokenPerBaseToken address of oracle `quoteToken` per `baseToken` that should implement `AggregatorV3Interface`
    /// @param feeToken address of feeToken
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quoteToken to be deposited after mint
    function mintTo(
        address to,
        uint16 strategyId,
        address oracleQuoteTokenPerFeeToken,
        address oracleQuoteTokenPerBaseToken,
        address feeToken,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) public override returns (uint256 poolId) {
        poolId = totalPools;
        address pool = factoryStrategy[strategyId].deploy(
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            quoteToken,
            baseToken
        );
        minter[poolId] = msg.sender;
        pools[poolId] = pool;
        poolIds[pool] = poolId;
        _mint(to, poolId);
        totalPools++;
        royaltyPrice[poolId] = calcInitialRoyaltyPrice(
            poolId,
            quoteTokenAmount
        );

        emit Mint(
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken
        );
        _deposit(
            poolId,
            quoteTokenAmount
        );
    }

    /// @notice deposit `quoteToken` to pool with `poolId`
    /// @dev callable only by owner of poolId
    /// @param poolId id of pool in array `pools`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return depositedAmount amount of deposited `quoteToken`
    function deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external override returns (uint256 depositedAmount) {
        _onlyOwnerOf(poolId);
        depositedAmount = _deposit(poolId, quoteTokenAmount);
    }

    /// @dev make transfer from msg.sender, approve to pool, call deposit on pool
    function _deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) internal returns (uint256 depositedAmount) {
        IPoolStrategy pool = IPoolStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        _checkCap(address(quoteToken), quoteTokenAmount);
        quoteToken.safeTransferFrom(
            msg.sender,
            address(this),
            quoteTokenAmount
        );
        quoteToken.forceApprove(address(pool), quoteTokenAmount);
        depositedAmount = pool.deposit(quoteTokenAmount);
        deposited[poolId][address(quoteToken)] += depositedAmount;
        _increaseTotalDeposited(address(quoteToken), depositedAmount);
        emit Deposit(
            poolIds[address(pool)],
            address(pool),
            address(quoteToken),
            depositedAmount
        );
    }

    /// @notice withdraw `quoteToken` from poolId to `msg.sender`
    /// @dev callcable only by owner of poolId
    function withdraw(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external override returns (uint256 withdrawn) {
        withdrawn = withdrawTo(poolId, msg.sender, quoteTokenAmount);
    }

    /// @notice withdraw `quoteToken` from poolId to `to`
    /// @dev callcable only by owner of poolId.
    /// @dev withdrawable when distrubution is 100% quoteToken + 0% baseToken
    /// @param poolId pool id of pool in array `pools`
    /// @param to address of receiver of withdrawed funds
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return withdrawn amount of withdrawn quoteToken
    function withdrawTo(
        uint256 poolId,
        address to,
        uint256 quoteTokenAmount
    ) public override returns (uint256 withdrawn) {
        _onlyOwnerOf(poolId);
        IPoolStrategy pool = IPoolStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        withdrawn = pool.withdraw(to, quoteTokenAmount);
        deposited[poolId][address(quoteToken)] -= withdrawn;
        _decreaseTotalDeposited(address(quoteToken), withdrawn);
        emit Withdraw(poolId, to, address(quoteToken), quoteTokenAmount);
    }

    /// @notice exit from strategy and transfer ownership to royalty receiver
    /// @dev callable only by owner of poolId
    /// @param poolId pool id of pool in array `pools`
    function exit(uint256 poolId)
        external
        override
        returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        _onlyOwnerOf(poolId);
        IPoolStrategy pool = IPoolStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        (quoteTokenAmount, baseTokenAmount) = pool.exit();
        transferFrom(ownerOf(poolId), getRoyaltyReceiver(poolId), poolId);
        _decreaseTotalDeposited(address(quoteToken), deposited[poolId][address(quoteToken)]);
        deposited[poolId][address(quoteToken)] = 0;
        emit Exit(poolId, quoteTokenAmount, baseTokenAmount);
    }

    /// @notice checks TVL of quoteToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quote token
    function _checkCap(address quoteToken, uint256 quoteTokenAmount) private view {
        if ((tokenCap[address(quoteToken)] > 0) && (tokenCap[address(quoteToken)] + quoteTokenAmount > tokenCap[address(quoteToken)])) {
            revert ExceededDepositCap();
        }
    }

    /// @notice increase Total Value Locked
    /// @param quoteToken address of quote token
    /// @param increaseAmount amount of quote token to increase TVL
    function _increaseTotalDeposited(address quoteToken, uint256 increaseAmount) private {
        totalDeposited[quoteToken] += increaseAmount;
    }

    /// @notice decrease Total Value Locked
    /// @param quoteToken address of quote token
    /// @param decreaseAmount amount of quote token to decrease TVL
    function _decreaseTotalDeposited(address quoteToken, uint256 decreaseAmount) private {
        if (totalDeposited[quoteToken] > decreaseAmount) {
            totalDeposited[quoteToken] -= decreaseAmount;
        } else {
            totalDeposited[quoteToken] = 0;
        }
    }

    /// @notice rebalance the pools with poolIds `poolId0` and `poolId1`
    /// @dev only owner of pools can rebalance with equal strategy id
    /// @param poolId0 pool id of pool to rebalance
    /// @param poolId1 pool id of pool to rebalance
    function rebalance(
        uint256 poolId0,
        uint256 poolId1
    ) external override {
        _onlyOwnerOf(poolId0);
        if (ownerOf(poolId0) != ownerOf(poolId1)) {
            revert NotAllowedToRebalance();
        }
        IPoolStrategy pool0 = IPoolStrategy(
            pools[poolId0]
        );
        IPoolStrategy pool1 = IPoolStrategy(
            pools[poolId1]
        );
        if (pool0.strategyId() != pool1.strategyId()) {
            revert DifferentStrategyId();
        }
        IToken pool0BaseToken = pool0.getBaseToken();
        IToken pool1BaseToken = pool1.getBaseToken();
        IToken pool0QuoteToken = pool0.getQuoteToken();
        IToken pool1QuoteToken = pool1.getQuoteToken();
        if (address(pool0QuoteToken) != address(pool1QuoteToken)) {
            revert DifferentQuoteTokens();
        }
        if (address(pool0BaseToken) != address(pool1BaseToken)) {
            revert DifferentBaseTokens();
        }

        (uint256 baseTokenAmount0, uint256 price0) = pool0.beforeRebalance();
        (uint256 baseTokenAmount1, uint256 price1) = pool1.beforeRebalance();
        // second step: rebalance
        uint256 totalBaseTokenAmount = baseTokenAmount0 +baseTokenAmount1;
        uint256 rebalancedPrice = (baseTokenAmount0 * price0 + baseTokenAmount1 * price1) / totalBaseTokenAmount;
        uint256 newBaseTokenAmount0 = totalBaseTokenAmount / 2;
        uint256 newBaseTokenAmount1 = totalBaseTokenAmount - newBaseTokenAmount0;

        pool0BaseToken.forceApprove(
            address(pool0),
            newBaseTokenAmount0
        );
        pool1BaseToken.forceApprove(
            address(pool1),
            newBaseTokenAmount1
        );
        pool0.afterRebalance(newBaseTokenAmount0, rebalancedPrice);
        pool1.afterRebalance(newBaseTokenAmount1, rebalancedPrice);
    }

    /// @notice grind the pool with `poolId`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    function grind(uint256 poolId) external override {
        uint256 gasStart = gasleft();
        IPoolStrategy pool = IPoolStrategy(pools[poolId]);
        bool successIterate;
        try pool.iterate() returns (bool iterated) {
            successIterate = iterated;
        } catch {
            successIterate = false;
        }
        uint256 grethReward = (gasStart - gasleft()) * tx.gasprice; // amount of native token used for grind 
        (address[] memory actors, uint256[] memory grethShares) = calcGRETHShares(
            poolId,
            grethReward,
            msg.sender
        );
        if (successIterate) {
            try grETH.mint(actors, grethShares) {} catch {}
        }
        lastGrinder = payable(msg.sender);
        emit Grind(poolId, msg.sender);
    }

    /// @notice buy royalty for pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @return royaltyPricePaid paid for royalty
    /// @return refund excess of msg.value
    function buyRoyalty(
        uint256 poolId
    )
        external
        payable
        override
        returns (uint256 royaltyPricePaid, uint256 refund)
    {
        (royaltyPricePaid, refund) = buyRoyaltyTo(poolId, payable(msg.sender));
    }

    /// @notice buy royalty for pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @return royaltyPricePaid paid for royalty
    /// @return refund excess of msg.value
    function buyRoyaltyTo(
        uint256 poolId,
        address payable to
    )
        public
        payable
        override
        nonReentrant
        returns (uint256 royaltyPricePaid, uint256 refund)
    {
        (
            uint256 compensationShare, // oldRoyaltyPrice + compensation
            uint256 poolOwnerShare,
            uint256 reserveShare,
            uint256 lastGrinderShare,
            /**uint256 oldRoyaltyPrice */,
            uint256 newRoyaltyPrice // compensationShare + poolOwnerShare + reserveShare + lastGrinderShare
        ) = calcRoyaltyPriceShares(poolId);
        if (msg.value < newRoyaltyPrice) {
            revert InsufficientRoyaltyPrice();
        }
        address payable oldRoyaltyReceiver = payable(getRoyaltyReceiver(poolId));
        // instantiate new royalty receiver
        royaltyReceiver[poolId] = to;
        royaltyPrice[poolId] = newRoyaltyPrice; // newRoyaltyPrice always increase!

        bool success;
        if (compensationShare > 0) {
            (success, ) = oldRoyaltyReceiver.call{value: compensationShare}("");
            if (!success) {
                (success, ) = address(grETH).call{value: compensationShare}(
                    ""
                );
                if (!success) {
                    revert FailCompensationShare();
                }
            }
            royaltyPricePaid += compensationShare;
        }
        if (poolOwnerShare > 0) {
            (success, ) = payable(ownerOf(poolId)).call{value: poolOwnerShare}("");
            if (!success) {
                (success, ) = address(grETH).call{value: poolOwnerShare}("");
                if (!success) {
                    revert FailPoolOwnerShare();
                }
            }
            royaltyPricePaid += poolOwnerShare;
        }
        if (reserveShare > 0) {
            (success, ) = address(grETH).call{value: reserveShare}("");
            if (!success) {
                (success, ) = owner.call{value: reserveShare}("");
                if (!success) {
                    revert FailPrimaryReceiverShare();
                }
            }
            royaltyPricePaid += reserveShare;
        }
        if (lastGrinderShare > 0) {
            (success, ) = lastGrinder.call{value: lastGrinderShare}("");
            if (!success) {
                (success, ) = address(grETH).call{value: lastGrinderShare}("");
                if (!success) {
                    revert FailLastGrinderShare();
                }
            }
            royaltyPricePaid += lastGrinderShare;
        }
        refund = msg.value - royaltyPricePaid;
        if (refund > 0) {
            (success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) {
                (success, ) = address(grETH).call{value: refund}("");
                if (!success) {
                    revert FailRefund();
                }
            }
        }
        emit BuyRoyalty(poolId, to, royaltyPricePaid);
    }

    /// @notice implementation of royalty standart ERC2981
    /// @param tokenId pool id of pool in array `pools`
    /// @param salePrice amount of asset
    /// @return receiver address of receiver
    /// @return royaltyAmount amount of royalty
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view override returns (address receiver, uint256 royaltyAmount) {
        uint256 poolId = tokenId;
        receiver = getRoyaltyReceiver(poolId);
        royaltyAmount = (salePrice * royaltyNumerator) / DENOMINATOR;
    }

    /// @notice calculates royalty shares
    /// @param poolId pool id of pool in array `pools`
    /// @param profit amount of token to be distributed
    /// @dev returns array of receivers and amounts
    function calcRoyaltyShares(
        uint256 poolId,
        uint256 profit
    )
        public
        view
        override
        returns (address[] memory receivers, uint256[] memory amounts)
    {
        receivers = new address[](4);
        amounts = new uint256[](4);
        receivers[0] = ownerOf(poolId); // pool owner
        receivers[1] = getRoyaltyReceiver(poolId); // royalty receiver
        receivers[2] = address(grETH);
        receivers[3] = lastGrinder; // last grinder
        uint256 denominator = DENOMINATOR;
        amounts[0] = (profit * poolOwnerShareNumerator) / denominator;
        amounts[1] = (profit * royaltyReceiverShareNumerator) / denominator;
        amounts[2] = (profit * royaltyReserveShareNumerator) / denominator;
        amounts[3] = profit - (amounts[0] + amounts[1] + amounts[2]);
    }

    /// @notice calc royalty prices
    /// @param poolId pool id of pool in array `pools`
    /// @return compensationShare feeToken amount to be received to old owner as compensation
    /// @return poolOwnerShare feeToken amount to be received by pool owner
    /// @return reserveShare feeToken amount to be received by primary royalty receiver
    /// @return lastGrinderShare feeToken amount to be received to last grinder
    /// @return oldRoyaltyPrice feeToken amount of old royalty price
    /// @return newRoyaltyPrice feeToken amount of new royalty price
    function calcRoyaltyPriceShares(
        uint256 poolId
    )
        public
        view
        returns (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 reserveShare,
            uint256 lastGrinderShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        )
    {
        uint256 _royaltyPrice = royaltyPrice[poolId];
        uint256 _denominator = DENOMINATOR;
        compensationShare =
            (_royaltyPrice * royaltyPriceCompensationShareNumerator) /
            _denominator;
        poolOwnerShare =
            (_royaltyPrice * royaltyPricePoolOwnerShareNumerator) /
            _denominator;
        reserveShare =
            (_royaltyPrice * royaltyPriceReserveShareNumerator) /
            _denominator;
        lastGrinderShare =
            (_royaltyPrice * royaltyPriceGrinderShareNumerator) /
            _denominator;
        oldRoyaltyPrice = _royaltyPrice;
        newRoyaltyPrice =
            compensationShare +
            poolOwnerShare +
            reserveShare +
            lastGrinderShare;
    }

    /// @notice calculates shares of grETH for actors
    /// @param poolId pool id of pool in array `pools`
    /// @param grethReward amount of grETH
    function calcGRETHShares(
        uint256 poolId,
        uint256 grethReward,
        address grinder
    )
        public
        view
        override
        returns (address[] memory actors, uint256[] memory grethShares)
    {
        actors = new address[](4);
        grethShares = new uint256[](4);
        uint16 denominator = DENOMINATOR;
        actors[0] = ownerOf(poolId); // poolOwner
        actors[1] = address(grETH); // grETH
        actors[2] = getRoyaltyReceiver(poolId); // royalty receiver
        actors[3] = grinder; // grinder

        grethShares[0] = (grethReward * grethPoolOwnerShareNumerator) / denominator; // (grethReward * (denominator - poolOwnerShareNumerator)) / denominator;
        grethShares[1] = (grethReward * grethReserveShareNumerator) / denominator;
        grethShares[2] = (grethReward * grethRoyaltyReceiverShareNumerator) / denominator;
        grethShares[3] = grethReward - (grethShares[0] + grethShares[1] + grethShares[2]);
    }

    /// @notice calc initial royalty price
    /// @param poolId pool id of pool in array `pools`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return initRoyaltyPrice fee token amount
    function calcInitialRoyaltyPrice(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) public view returns (uint256 initRoyaltyPrice) {
        uint256 feeTokenAmount = IPoolStrategy(pools[poolId]).calcFeeTokenByQuoteToken(quoteTokenAmount);
        initRoyaltyPrice = (feeTokenAmount * royaltyInitPriceNumerator) / DENOMINATOR;
    }

    /// @notice returns tokenURI of `tokenId`
    /// @param poolId pool id of pool in array `pools`
    /// @return uri unified reference indentificator for `tokenId`
    function tokenURI(
        uint256 poolId
    )
        public
        view
        override(ERC721, IPoolsNFT)
        returns (string memory uri)
    {
        _requireOwned(poolId);
        // https://raw.githubusercontent.com/TriplePanicLabs/GrindURUS-PoolsNFTsData/refs/heads/main/arbitrum/{poolId}.json
        string memory path = string.concat(baseURI, poolId.toString());
        uri = string.concat(path, ".json");
    }

    /// @inheritdoc ERC721
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable, IERC165) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId);
    }

    /// @notice return royalty receiver
    /// @param poolId pool id of pool in array `pools`
    /// @return receiver address of royalty receiver
    function getRoyaltyReceiver(
        uint256 poolId
    ) public view returns (address receiver) {
        receiver = royaltyReceiver[poolId];
        if (receiver == address(0)) {
            receiver = ownerOf(poolId);
        }
    }

    /// @notice gets pool ids owned by `poolOwner`
    /// @param poolOwner address of pool owner
    /// @return totalPoolIds total amount of pool ids owned by `poolOwner`
    /// @return poolIdsOwnedByPoolOwner array of owner pool ids
    function getPoolIdsOf(
        address poolOwner
    )
        external
        view
        returns (uint256 totalPoolIds, uint256[] memory poolIdsOwnedByPoolOwner)
    {
        totalPoolIds = balanceOf(poolOwner);
        if (totalPoolIds == 0) {
            return (0, new uint256[](1));
        }
        uint256 i = 0;
        poolIdsOwnedByPoolOwner = new uint256[](totalPoolIds);
        for (; i < totalPoolIds; ) {
            poolIdsOwnedByPoolOwner[i] = tokenOfOwnerByIndex(poolOwner, i);
            unchecked {
                ++i;
            }
        }
        return (totalPoolIds, poolIdsOwnedByPoolOwner);
    }

    /// @notice pagination for table on dashboard with poolNFT info
    /// @param fromPoolId pool id from
    /// @param toPoolId pool id to
    function getPoolNFTInfos(
        uint256 fromPoolId,
        uint256 toPoolId
    ) external view returns (PoolNFTInfo[] memory poolsInfo) {
        if (fromPoolId > toPoolId) {
            revert InvalidPoolNFTInfos();
        }
        poolsInfo = new PoolNFTInfo[](toPoolId - fromPoolId + 1);
        uint256 poolId = fromPoolId;
        uint256 poolInfoId = 0;
        for (; poolId <= toPoolId; ) {
            IPoolStrategy pool = IPoolStrategy(pools[poolId]);
            IToken quoteToken = pool.getQuoteToken();
            IToken baseToken = pool.getBaseToken();
            (
                uint256 quoteTokenYieldProfit,
                uint256 baseTokenYieldProfit,
                uint256 quoteTokenTradeProfit,
                uint256 baseTokenTradeProfit
            ) = pool.getTotalProfits();
            (uint256 APRNumerator, uint256 APRDenominator) = pool.APR();
            poolsInfo[poolInfoId] = PoolNFTInfo({
                poolId: poolId,
                strategyId: pool.strategyId(),
                quoteToken: address(quoteToken),
                baseToken: address(baseToken),
                quoteTokenSymbol: quoteToken.symbol(),
                baseTokenSymbol: baseToken.symbol(),
                quoteTokenAmount: pool.getQuoteTokenAmount(),
                baseTokenAmount: pool.getBaseTokenAmount(),
                quoteTokenYieldProfit: quoteTokenYieldProfit,
                baseTokenYieldProfit: baseTokenYieldProfit,
                quoteTokenTradeProfit: quoteTokenTradeProfit,
                baseTokenTradeProfit: baseTokenTradeProfit,
                APRNumerator: APRNumerator,
                APRDenominator: APRDenominator,
                royaltyPrice: royaltyPrice[poolId]
            });
            unchecked {
                poolId++;
                poolInfoId++;
            }
        }
    }

    /// @notice return TVL of pool with `poolId`
    /// @param poolId id of pool
    function getTVL(uint256 poolId) external view override returns (uint256) {
        return IPoolStrategy(pools[poolId]).getTVL();
    }

    /// @notice returns long position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getLong(
        uint256 poolId
    )
        external
        view
        override
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        )
    {
        (
            number,
            numberMax,
            priceMin,
            liquidity,
            qty,
            price,
            feeQty,
            feePrice
        ) = IPoolStrategy(pools[poolId]).getLong();
    }

    /// @notice returns hedge position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getHedge(
        uint256 poolId
    )
        external
        view
        override
        returns (
            uint8 number,
            uint8 numberMax,
            uint256 priceMin,
            uint256 liquidity,
            uint256 qty,
            uint256 price,
            uint256 feeQty,
            uint256 feePrice
        )
    {
        (
            number,
            numberMax,
            priceMin,
            liquidity,
            qty,
            price,
            feeQty,
            feePrice
        ) = IPoolStrategy(pools[poolId]).getHedge();
    }

    /// @notice returns long position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getConfig(
        uint256 poolId
    )
        external
        view
        override
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 averagePriceVolatility,
            uint256 extraCoef,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        )
    {
        IPoolStrategy pool = IPoolStrategy(pools[poolId]);
        (
            longNumberMax,
            hedgeNumberMax,
            averagePriceVolatility,
            extraCoef,
            returnPercentLongSell,
            returnPercentHedgeSell,
            returnPercentHedgeRebuy
        ) = pool.getConfig();
    }

    /// @notice sweep token from this smart contract to `to`
    /// @param token address of ERC20 token
    /// @param to address of receiver fee amount
    function sweep(address token, address to) external payable {
        _onlyOwner();
        uint256 balance;
        if (token == address(0)) {
            balance = address(this).balance;
            if (balance == 0) {
                revert ZeroETH();
            }
            (bool success, ) = payable(to).call{value: balance}("");
            if (!success) {
                revert FailETHTransfer();
            }
        } else {
            balance = IToken(token).balanceOf(address(this));
            if (balance == 0) {
                revert FailTokenTransfer(token);
            }
            IToken(token).safeTransfer(to, balance);
        }
    }

    receive() external payable {
        if (msg.value > 0) {
            (bool success, ) = owner.call{value: msg.value}("");
            if (!success) {
                emit ReceiveETH(msg.value);
            }
        }
    }
}
