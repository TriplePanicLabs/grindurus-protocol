// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT, IPoolsNFTLens, IGRETH, IGrinderAI} from "src/interfaces/IPoolsNFT.sol";
import {IStrategy, IURUS} from "src/interfaces/IStrategy.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IStrategyFactory} from "src/interfaces/IStrategyFactory.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {ERC721, ERC721Enumerable, IERC165} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title GrindURUS Pools NFT
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice NFT that represets ownership of every grindurus strategy pools
contract PoolsNFT is IPoolsNFT, ERC721Enumerable {
    using SafeERC20 for IToken;

    //// CONTSTANTS ////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    //// ROYALTY PRICE PARAMS AND SHARES //////////////////////////////////////////////////////////////////////////////////////////////////
    /// require CompensationShareNumerator + ReserveShareNumerator + PoolOwnerShareNumerator + OwnerShareNumerator > 100%

    /// @dev numerator of init royalty price
    uint16 public royaltyPriceInitNumerator;

    /// @dev numerator of royalty price compensation to previous owner share
    uint16 public royaltyPriceCompensationShareNumerator;

    /// @dev numerator of royalty price primary receiver share
    uint16 public royaltyPriceReserveShareNumerator;

    /// @dev numerator of royalty price pool owner share
    uint16 public royaltyPricePoolOwnerShareNumerator;

    /// @dev numerator of royalty price owner share
    uint16 public royaltyPriceOwnerShareNumerator;

    //// GRETH SHARES //////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev numerator of grinder share 
    /// @dev grETHGrinderShareNumerator == 80_00 == 80%
    uint16 public grethGrinderShareNumerator;

    /// @dev numerator of grETH reserve share
    /// @dev grETHReserveShareNumerator == 15_00 == 15%
    uint16 public grethReserveShareNumerator;

    /// @dev numerator of pool owner share
    /// @dev example: grETHPoolOwnerShareNumerator == 2_00 == 2%
    uint16 public grethPoolOwnerShareNumerator;

    /// @dev numerator of royalty receiver share
    /// @dev example: grETHRoyaltyReceiverShareNumerator == 3_00 == 3%
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
    /// @dev example: royaltyReceiverShareNumerator == 10_00 == 10%
    uint16 public royaltyReceiverShareNumerator;

    /// @notice royalty share of reserve. Reserve on grETH
    /// @dev example: poolOwnerShareNumerator == 5_00 == 5%
    uint16 public royaltyReserveShareNumerator;

    /// @notice royalty share of owner
    /// @dev example: royaltyOwnerShareNumerator == 5_00 == 5%
    uint16 public royaltyOwnerShareNumerator;

    //// PoolsNFT OWNERSHIP DATA ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev address of pending owner
    address payable public pendingOwner;

    /// @dev address of grindurus protocol owner. For DAO
    address payable public owner;

    //// POOLSNFT DATA /////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice address of poolsNFTLens
    IPoolsNFTLens public poolsNFTLens;

    /// @notice reserve for accumulation of percent of strategy profits
    /// @dev grETH token address
    IGRETH public grETH;

    /// @dev address of grinderAI smart contract
    IGrinderAI public grinderAI;

    /// @notice total amount of pools
    uint256 public totalPools;

    /// @dev strategyId => address of grindurus pool strategy implementation
    mapping (uint16 strategyId => address) public strategyFactory;

    /// @dev strategyId => is strategy stoped. true - stopped. false - not stopped
    /// @dev by default strategy is not stopped
    mapping (uint16 strategyId => bool) public isStrategyStopped;

    /// @dev poolId => royalty receiver
    mapping (uint256 poolId => address) public royaltyReceiver;

    /// @dev poolId => royalty price
    /// @dev [royalty price] = quote token of pool id
    mapping (uint256 poolId => uint256) public royaltyPrice;

    /// @notice store minter of pool for airdrop points
    /// @dev poolId => address of creator of NFT
    mapping (uint256 poolId => address) public minter;

    /// @dev poolId => pool strategy address
    mapping (uint256 poolId => address) public pools;

    /// @dev pool strategy address => poolId
    mapping (address pool => uint256) public poolIds;

    /// @dev token address => minimum amount to deposit
    /// @dev if minDeposit == 0, that no limit for minimum deposit
    mapping (address token => uint256) public minDeposit;

    /// @dev token address => maximum amount of deposit
    /// @dev if maxDeposit == 0, that no limut for maximum deposit
    mapping (address token => uint256) public maxDeposit;

    /// @dev owner of address => agent address => is agent of `_ownerOf`
    /// @dev true - is agent. False - is not agent
    /// @dev if _agent is grinderAI, than true - is not agent, false - is agent
    mapping (address _ownerOf => mapping (address _agent => bool)) internal _agentApprovals;

    /// @dev pool id => owner of pool => depositor => is approved. true - approved, false - not approved
    /// @dev true - is eligible depositor. false - is not eligible depositor
    mapping (uint256 poolId => mapping (address _ownerOf => mapping(address depositor => bool))) internal _depositorApprovals;

    constructor() ERC721("", "") {
        totalPools = 0;
        pendingOwner = payable(address(0));
        owner = payable(msg.sender);

        royaltyPriceInitNumerator = 1_00; // 1%
        royaltyPriceCompensationShareNumerator = 101_00; // 101%
        royaltyPriceReserveShareNumerator = 1_00; // 1%
        royaltyPricePoolOwnerShareNumerator = 5_00; // 5%
        royaltyPriceOwnerShareNumerator = 1_00; // 1%
        // total royalty price = 101% + 1% + 5% + 1% = 108% > 100%
        require(royaltyPriceCompensationShareNumerator + royaltyPriceReserveShareNumerator + royaltyPricePoolOwnerShareNumerator + royaltyPriceOwnerShareNumerator > DENOMINATOR);

        grethGrinderShareNumerator = 80_00; // 80%
        grethReserveShareNumerator = 15_00; // 15%
        grethPoolOwnerShareNumerator = 2_00; // 2%
        grethRoyaltyReceiverShareNumerator = 3_00; // 3%;
        // total greth share = 80% + 15% + 2% + 3% = 100%
        require(grethGrinderShareNumerator + grethReserveShareNumerator + grethPoolOwnerShareNumerator + grethRoyaltyReceiverShareNumerator == DENOMINATOR);

        // poolOwnerShareNumerator + royaltyReserveShareNumerator + royaltyReceiverShareNumerator + royaltyOwnerShareNumerator == DENOMINATOR
        royaltyNumerator = 20_00; // 20%
        poolOwnerShareNumerator = 80_00; // 80%
        royaltyReceiverShareNumerator = 10_00; // 10%
        royaltyReserveShareNumerator = 5_00; // 5%
        royaltyOwnerShareNumerator = 5_00; // 5%
        // total royalty + owner share = 20% + 80% = 100%
        // total royalty share = 80% + 10% + 5% + 5% = 100%
        require(royaltyNumerator + poolOwnerShareNumerator == DENOMINATOR);
        require(poolOwnerShareNumerator + royaltyReceiverShareNumerator + royaltyReserveShareNumerator + royaltyOwnerShareNumerator == DENOMINATOR);
        //  profit = 1 USDT
        //  profit to pool owner = 1 * (80%) = 0.8 USDT
        //  royalty = 1 * 20% = 0.2 USDT
        //      royalty to reserve  = 0.2 * 4% = 0.008 USDT
        //      royalty to royaly receiver = 0.2 * 15% = 0.03 USDT
        //      royalty grinder = 0.2 * 1% = 0.002 USDT
    }

    /// @notice sets grETH token
    /// @dev callable only by owner
    function init(address _poolsNFTLens, address _grETH, address _grinderAI) external override {
        _onlyOwner();
        require(address(poolsNFTLens) == address(0) && address(grETH) == address(0) && address(grinderAI) == address(0));
        poolsNFTLens = IPoolsNFTLens(_poolsNFTLens);
        grETH = IGRETH(_grETH);
        grinderAI = IGrinderAI(_grinderAI);
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    /// @notice checks that msg.sender is agent
    function _onlyAgentOf(uint256 poolId) private view {
        if (!isAgentOf(ownerOf(poolId), msg.sender)) {
            revert NotAgent();
        }
    }

    /// @notice checks that msg.sender is owner of pool id
    function _onlyOwnerOf(uint256 poolId) private view {
        if (msg.sender != ownerOf(poolId)) {
            revert NotOwnerOf();
        }
    }

    /////// ONLY OWNER FUNCTIONS

    /// @notice sets pools NFT Image
    /// @param _poolsNFTLens address of poolsNFTLens
    function setPoolsNFTLens(address _poolsNFTLens) external override {
        _onlyOwner();
        poolsNFTLens = IPoolsNFTLens(_poolsNFTLens);
        require(address(poolsNFTLens.poolsNFT()) == address(this));
    }

    /// @notice sets minimum deposit
    /// @param token address of token
    /// @param _minDeposit minimum amount of deposit
    function setMinDeposit(address token, uint256 _minDeposit) external override {
        _onlyOwner();
        minDeposit[token] = _minDeposit;
    }

    /// @notice sets maximum deposit
    /// @param token address of token
    /// @param _maxDeposit maximum amount of deposit
    function setMaxDeposit(address token, uint256 _maxDeposit) external override {
        _onlyOwner();
        maxDeposit[token] = _maxDeposit;
    }

    /// @notice set royalty price init numerator
    /// @param _royaltyPriceInitNumerator numerator of royalty price init
    function setRoyaltyPriceInitNumerator(uint16 _royaltyPriceInitNumerator) external override {
        _onlyOwner();
        if (_royaltyPriceInitNumerator >= DENOMINATOR) {
            revert InvalidRoyaltyPriceInit();
        }
        royaltyPriceInitNumerator = _royaltyPriceInitNumerator;
    }

    /// @notice sets royalty price share to actors
    /// @dev callable only by owner
    function setRoyaltyPriceShares(
        uint16 _royaltyPriceCompensationShareNumerator,
        uint16 _royaltyPriceReserveShareNumerator,
        uint16 _royaltyPricePoolOwnerShareNumerator,
        uint16 _royaltyPriceOwnerShareNumerator
    ) external override {
        _onlyOwner();
        if (_royaltyPriceCompensationShareNumerator <= DENOMINATOR) {
            revert InvalidShares();
        }
        royaltyPriceCompensationShareNumerator = _royaltyPriceCompensationShareNumerator;
        royaltyPriceReserveShareNumerator = _royaltyPriceReserveShareNumerator;
        royaltyPricePoolOwnerShareNumerator = _royaltyPricePoolOwnerShareNumerator;
        royaltyPriceOwnerShareNumerator = _royaltyPriceOwnerShareNumerator;
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
            revert InvalidShares();
        }
        grethGrinderShareNumerator = _grethGrinderShareNumerator;
        grethReserveShareNumerator = _grethReserveShareNumerator;
        grethPoolOwnerShareNumerator = _grethPoolOwnerShareNumerator;
        grethRoyaltyReceiverShareNumerator = _grethRoyaltyReceiverShareNumerator;
    }

    /// @notice sets primary receiver royalty share
    /// @dev callable only by owner
    function setRoyaltyShares(
        uint16 _poolOwnerRoyaltyShareNumerator,
        uint16 _royaltyReceiverShareNumerator,
        uint16 _royaltyReserveShareNumerator,
        uint16 _royaltyOwnerShareNumerator
    ) external override {
        _onlyOwner();
        if (_poolOwnerRoyaltyShareNumerator + _royaltyReceiverShareNumerator + _royaltyReserveShareNumerator + _royaltyOwnerShareNumerator != DENOMINATOR) {
            revert InvalidShares();
        }
        royaltyNumerator = DENOMINATOR - _poolOwnerRoyaltyShareNumerator;
        poolOwnerShareNumerator = _poolOwnerRoyaltyShareNumerator;
        royaltyReceiverShareNumerator = _royaltyReceiverShareNumerator;
        royaltyReserveShareNumerator = _royaltyReserveShareNumerator;
        royaltyOwnerShareNumerator = _royaltyOwnerShareNumerator;
    }

    /// @notice First step - transfering ownership to `newOwner`
    ///         Second step - accept ownership
    /// @dev for future DAO
    function transferOwnership(address payable newOwner) external override {
        if (payable(msg.sender) == owner) {
            pendingOwner = newOwner;
        } else if (payable(msg.sender) == pendingOwner) {
            owner = pendingOwner;
            pendingOwner = payable(address(0));
        } else {
            revert NotOwner();
        }
    }

    /// @notice set factrory strategy
    /// @dev callable only by strategiest
    function setStrategyFactory(address _strategyFactory) external override {
        _onlyOwner();
        uint16 strategyId = IStrategyFactory(_strategyFactory).strategyId();
        strategyFactory[strategyId] = _strategyFactory;
        isStrategyStopped[strategyId] = false;
    }

    /// @notice set stop on strategy with `strategyId`
    /// @param strategyId id of strategy
    /// @param _isStrategyStopped is strategy stopped. true - stopped. false - not stopped
    function setStrategyStopped(uint16 strategyId, bool _isStrategyStopped) public override {
        _onlyOwner();
        isStrategyStopped[strategyId] = _isStrategyStopped;
    }

    /////// PUBLIC FUNCTIONS

    /// @notice mints NFT with deployment of strategy
    /// @dev mints to `msg.sender`
    /// @param strategyId id of strategy implementation
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quoteToken to be deposited after mint
    function mint(
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) external override returns (uint256) {
        return mintTo(
            msg.sender,
            strategyId,
            baseToken,
            quoteToken,
            quoteTokenAmount
        );
    }

    /// @notice mints NFT with deployment of strategy
    /// @dev mints to `to`
    /// @param strategyId id of strategy implementation
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quoteToken to be deposited after mint
    function mintTo(
        address to,
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount
    ) public override returns (uint256 poolId) {
        if (isStrategyStopped[strategyId]) {
            revert StrategyStopped();
        }
        poolId = _mintTo(to, strategyId, baseToken, quoteToken);
        if (quoteTokenAmount == 0) {
            require(msg.sender == address(grinderAI));
        } else {
            _deposit(
                poolId,
                quoteTokenAmount
            );
            royaltyPrice[poolId] = (quoteTokenAmount * royaltyPriceInitNumerator) / DENOMINATOR;
        }
    }

    /// @notice mint NFT and deploy strategy
    /// @dev mints to `to`
    /// @param strategyId id of strategy implementation
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    function _mintTo(
        address to,
        uint16 strategyId,
        address baseToken,
        address quoteToken
    ) internal returns (uint256 poolId) {
        poolId = totalPools;
        address pool = IStrategyFactory(strategyFactory[strategyId]).deploy(
            poolId,
            baseToken,
            quoteToken
        );
        minter[poolId] = msg.sender;
        pools[poolId] = pool;
        poolIds[pool] = poolId;
        _mint(to, poolId);
        totalPools++;

        emit Mint(
            poolId,
            baseToken,
            quoteToken
        );
    }

    /// @notice approve depositor of pool
    /// @param poolId id of pool in array `pools`
    /// @param depositor address of depositor
    /// @param _depositorApproval true - depositor approved, false depositor not approved
    function setDepositor(uint256 poolId, address depositor, bool _depositorApproval) external override {
        _onlyOwnerOf(poolId);
        _depositorApprovals[poolId][ownerOf(poolId)][depositor] = _depositorApproval;
    }

    /// @notice deposit `quoteToken` to pool with `poolId`
    /// @dev callable only by owner of poolId
    /// @param poolId id of pool in array `pools`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return depositedAmount amount of deposited `quoteToken`
    function deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) external override returns (uint256) {
        if (!isDepositorOf(poolId, msg.sender)) {
            revert NotDepositor();
        }
        return _deposit(poolId, quoteTokenAmount);
    }

    /// @notice deposit `baseToken` to pool with `poolId`
    /// @dev callable only by owner of poolId
    /// @param poolId id of pool in array `pools`
    /// @param baseTokenAmount amount of `baseToken`
    /// @param baseTokenPrice price of baseToken
    /// @return depositedBaseTokenAmount amount of deposited `quoteToken`
    function deposit2(
        uint256 poolId,
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) external override returns (uint256 depositedBaseTokenAmount) {
        if (!isDepositorOf(poolId, msg.sender)) {
            revert NotDepositor();
        }
        IStrategy pool = IStrategy(pools[poolId]);
        IToken baseToken = pool.baseToken();
        baseToken.safeTransferFrom(
            msg.sender,
            address(this),
            baseTokenAmount
        );
        baseToken.forceApprove(address(pool), baseTokenAmount);
        depositedBaseTokenAmount = pool.deposit2(
            baseTokenAmount,
            baseTokenPrice
        );
        emit Deposit2(
            poolId, 
            address(pool), 
            address(baseToken), 
            baseTokenAmount, 
            baseTokenPrice
        );
    }

    /// @notice dip rebalance mechanism via quoteToken
    /// @dev aggregate quoteTokenAmount to pool
    /// @param poolId pool id of pool to dip
    /// @param quoteTokenAmount quote token amount
    function deposit3(uint256 poolId, uint256 quoteTokenAmount) external override {
        if (!isDepositorOf(poolId, msg.sender)) {
            revert NotDepositor();
        }
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        quoteToken.safeTransferFrom(msg.sender, address(this), quoteTokenAmount);
        quoteToken.forceApprove(address(pool), quoteTokenAmount);
        pool.deposit3(quoteTokenAmount);
        emit Deposit3(
            poolId,
            address(pool),
            address(quoteToken),
            quoteTokenAmount
        );
    }

    /// @dev make transfer from msg.sender, approve to pool, call deposit on pool
    function _deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) internal returns (uint256 depositedAmount) {
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        _checkMinDeposit(address(quoteToken), quoteTokenAmount);
        _checkMaxDeposit(address(quoteToken), quoteTokenAmount);
        quoteToken.safeTransferFrom(
            msg.sender,
            address(this),
            quoteTokenAmount
        );
        quoteToken.forceApprove(address(pool), quoteTokenAmount);
        depositedAmount = pool.deposit(quoteTokenAmount);
        emit Deposit(
            poolId,
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
    ) external override returns (uint256) {
        return withdrawTo(poolId, msg.sender, quoteTokenAmount);
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
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        withdrawn = pool.withdraw(to, quoteTokenAmount);
        emit Withdraw(poolId, to, address(quoteToken), quoteTokenAmount);
    }

    /// @notice exit from strategy and transfer ownership to royalty receiver
    /// @dev callable only by owner of poolId
    /// @param poolId pool id of pool in array `pools`
    function exit(
        uint256 poolId
    ) external override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount)
    {
        _onlyOwnerOf(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        (quoteTokenAmount, baseTokenAmount) = pool.exit();
        emit Exit(poolId, quoteTokenAmount, baseTokenAmount);
    }

    /// @notice checks min deposit
    function _checkMinDeposit(address quoteToken, uint256 depositAmount) private view {
        if (depositAmount < minDeposit[quoteToken]) {
            revert InsufficientMinDeposit();
        }
    }

    /// @notice checks TVL of quoteToken
    /// @param quoteToken address of quoteToken
    /// @param depositAmount amount of quote token
    function _checkMaxDeposit(address quoteToken, uint256 depositAmount) private view {
        if (maxDeposit[quoteToken] != 0 && depositAmount > maxDeposit[quoteToken]) {
            revert ExceededMaxDeposit();
        }
    }

    /// @notice checks capital on pool
    /// @param pool address of pool
    function _checkCapital(IStrategy pool) private view {
        if (pool.getActiveCapital() == 0) {
            revert NoCapital();
        }
    }

    /// @notice approve agent to msg.sender
    /// @dev by default grinderAI is agent. If user wants to directly disaprove grinderAI, it call setAgent with _agentApproval==false
    ///      if agent is grinderAI, than under the hood _agentApproval it will inversed. 
    ///      The function `isAgent` will handle inversed approval properly
    /// @param _agent address of agent
    /// @param _agentApproval true - agent approved, false - agent not approved
    function setAgent(address _agent, bool _agentApproval) external override {
        if (_agent == address(grinderAI)) {
            _agentApprovals[msg.sender][_agent] = !_agentApproval;
        } else{
            _agentApprovals[msg.sender][_agent] = _agentApproval;
        }
    }

    /// @notice rebalance the pools with poolIds `poolId0` and `poolId1`
    /// @dev only owner or AI-agent of pools can rebalance with equal strategy id
    /// @param poolId0 pool id of pool to rebalance
    /// @param poolId1 pool id of pool to rebalance
    /// @param rebalance0 left fraction of rebalanced amount
    /// @param rebalance1 right fraction of rebalanced amount
    function rebalance(
        uint256 poolId0,
        uint256 poolId1,
        uint8 rebalance0,
        uint8 rebalance1
    ) external override {
        if (ownerOf(poolId0) != ownerOf(poolId1)) {
            revert DifferentOwnersOfPools();
        }
        _onlyAgentOf(poolId0);
        IStrategy pool0 = IStrategy(pools[poolId0]);
        IStrategy pool1 = IStrategy(pools[poolId1]);
        if (address(pool0.quoteToken()) != address(pool1.quoteToken()) || address(pool0.baseToken()) != address(pool1.baseToken())) {
            revert DifferentTokens();
        }

        (uint256 baseTokenAmount0, uint256 price0) = pool0.beforeRebalance();
        pool0.baseToken().safeTransferFrom(address(pool0), address(this), baseTokenAmount0);
        (uint256 baseTokenAmount1, uint256 price1) = pool1.beforeRebalance();
        pool1.baseToken().safeTransferFrom(address(pool1), address(this), baseTokenAmount1);

        // second step: rebalance
        uint256 totalBaseTokenAmount = baseTokenAmount0 + baseTokenAmount1;
        uint256 rebalancedPrice = ((baseTokenAmount0 * price0) + (baseTokenAmount1 * price1)) / totalBaseTokenAmount;
        uint256 newBaseTokenAmount0 = (rebalance0 * totalBaseTokenAmount) / (rebalance0 + rebalance1);
        uint256 newBaseTokenAmount1 = totalBaseTokenAmount - newBaseTokenAmount0;

        if (newBaseTokenAmount0 > 0) {
            pool0.baseToken().forceApprove(
                address(pool0),
                newBaseTokenAmount0
            );
        }
        pool0.afterRebalance(newBaseTokenAmount0, rebalancedPrice);

        if (newBaseTokenAmount1 > 0) {
            pool1.baseToken().forceApprove(
                address(pool1),
                newBaseTokenAmount1
            );
        }
        pool1.afterRebalance(newBaseTokenAmount1, rebalancedPrice);

        emit Rebalance(
            poolId0,
            poolId1,
            rebalancedPrice,
            newBaseTokenAmount0,
            newBaseTokenAmount1
        );
    }

    /// @notice grind the pool with `poolId`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    function grind(uint256 poolId) external override returns (bool) {
        return grindTo(poolId, msg.sender);
    }

    /// @notice grind the pool with `poolId` and grinder is `to`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    /// @param grinder address of grinder, that will receive grind reward
    function grindTo(uint256 poolId, address grinder) public override returns (bool isGrinded) {
        uint256 gasStart = gasleft();
        IStrategy pool = IStrategy(pools[poolId]);
        _checkCapital(pool);
        try pool.iterate() returns (bool iterated) {
            isGrinded = iterated;
        } catch {
            isGrinded = false;
        }
        if (isGrinded) {
            uint256 grethReward = (gasStart - gasleft()) * tx.gasprice; // amount of native token used for grind 
            _reward(poolId, grethReward, grinder);
            emit Grind(poolId, type(uint8).max, grinder, isGrinded);
        }
    }

    /// @notice grind the exact operation on the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @param op operation on strategy pool
    function grindOp(uint256 poolId, uint8 op) external returns (bool) {
        return grindOpTo(poolId, op, msg.sender);
    }

    /// @notice grind the exact operation on the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @param op operation on strategy pool
    /// @param grinder address of grinder, that will receive grind reward
    function grindOpTo(uint256 poolId, uint8 op, address grinder) public override returns (bool isGrinded) {
        uint256 gasStart = gasleft();
        IStrategy pool = IStrategy(pools[poolId]);
        _checkCapital(pool);
        if (op == uint8(IURUS.Op.LONG_BUY)) {
            try pool.long_buy() {
                isGrinded = true;
            }
            catch {}
        } else if (op == uint8(IURUS.Op.LONG_SELL)) {
            try pool.long_sell() {
                isGrinded = true;
            }
            catch {}
        } else if (op == uint8(IURUS.Op.HEDGE_SELL)) {
            try pool.hedge_sell() {
                isGrinded = true;
            }
            catch {}
        } else if (op == uint8(IURUS.Op.HEDGE_REBUY)) {
            try pool.hedge_rebuy() {
                isGrinded = true;
            }
            catch {}
        } else {
            revert InvalidOp();
        }
        if (isGrinded) {
            uint256 grethReward = (gasStart - gasleft()) * tx.gasprice; // amount of native token used for grind 
            _reward(poolId, grethReward, grinder);
            emit Grind(poolId, op, grinder, isGrinded);
        }
    }

    /// @notice rewards the grinder
    function _reward(uint256 poolId, uint256 grethReward, address grinder) internal {
        (address[] memory actors, uint256[] memory grethShares) = calcGRETHShares(
            poolId,
            grethReward,
            grinder
        );
        try grETH.mint(actors, grethShares) {} catch {}
    }

    /// @notice transfert poolId from `msg.sender` to `to`
    /// @param to address of pool receiver
    /// @param poolId pool id of pool in array `pools`
    function transfer(address to, uint256 poolId) public {
        _transfer(msg.sender, to, poolId);
    }

    /// @notice buy royalty for pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @return royaltyPricePaid paid for royalty
    function buyRoyalty(
        uint256 poolId
    ) external override returns (uint256) {
        return buyRoyaltyTo(poolId, msg.sender);
    }

    /// @notice buy royalty for pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @return royaltyPricePaid paid for royalty
    function buyRoyaltyTo(
        uint256 poolId,
        address to
    ) public override returns (uint256 royaltyPricePaid) {
        (
            uint256 compensationShare, // oldRoyaltyPrice + compensation
            uint256 poolOwnerShare,
            uint256 reserveShare,
            uint256 ownerShare,
            /**uint256 oldRoyaltyPrice */,
            uint256 newRoyaltyPrice // compensationShare + poolOwnerShare + reserveShare + ownerShare
        ) = calcRoyaltyPriceShares(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        quoteToken.safeTransferFrom(msg.sender, address(this), newRoyaltyPrice);
        
        address oldRoyaltyReceiver = getRoyaltyReceiver(poolId);
        royaltyReceiver[poolId] = to;
        royaltyPrice[poolId] = newRoyaltyPrice;

        if (compensationShare > 0) {
            quoteToken.safeTransfer(oldRoyaltyReceiver, compensationShare);
            royaltyPricePaid += compensationShare;
        }
        if (poolOwnerShare > 0) {
            quoteToken.safeTransfer(ownerOf(poolId), poolOwnerShare);
            royaltyPricePaid += poolOwnerShare;
        }
        if (reserveShare > 0) {
            quoteToken.safeTransfer(address(grETH), reserveShare);
            royaltyPricePaid += reserveShare;
        }
        if (ownerShare > 0) {
            quoteToken.safeTransfer(owner, ownerShare);
            royaltyPricePaid += ownerShare;
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
        receiver = getRoyaltyReceiver(tokenId);
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
        receivers[2] = (address(grETH) != address(0)) ? address(grETH) : owner; // reserve
        receivers[3] = owner; // owner
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
    /// @return ownerShare feeToken amount to be received to last grinder
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
            uint256 ownerShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        )
    {
        uint256 _royaltyPrice = royaltyPrice[poolId];
        uint256 _denominator = DENOMINATOR;
        if (_royaltyPrice > 0) {
            compensationShare = (_royaltyPrice * royaltyPriceCompensationShareNumerator) / _denominator;
            poolOwnerShare = (_royaltyPrice * royaltyPricePoolOwnerShareNumerator) / _denominator;
            reserveShare = (_royaltyPrice * royaltyPriceReserveShareNumerator) / _denominator;
            ownerShare = (_royaltyPrice * royaltyPriceOwnerShareNumerator) / _denominator;
            oldRoyaltyPrice = _royaltyPrice;
            newRoyaltyPrice = compensationShare + poolOwnerShare + reserveShare + ownerShare;
        } else {
            newRoyaltyPrice = IStrategy(pools[poolId]).getActiveCapital() * royaltyPriceInitNumerator / _denominator;
        }
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
        actors[1] = address(grETH) != address(0) ? address(grETH) : owner; // grETH
        actors[2] = getRoyaltyReceiver(poolId); // royalty receiver
        actors[3] = grinder; // grinder

        grethShares[0] = (grethReward * grethPoolOwnerShareNumerator) / denominator;
        grethShares[1] = (grethReward * grethReserveShareNumerator) / denominator;
        grethShares[2] = (grethReward * grethRoyaltyReceiverShareNumerator) / denominator;
        grethShares[3] = grethReward - (grethShares[0] + grethShares[1] + grethShares[2]);
    }

    /// @notice return base URI
    /// @dev base URI holds on poolsNFTLens
    function baseURI() public view returns (string memory) {
        return poolsNFTLens.baseURI();
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
        uri = poolsNFTLens.tokenURI(poolId);
    }

    /// @notice return the name of PoolsNFT
    function name() public pure override returns (string memory) {
        return "GrindURUS Pools Collection";
    }

    /// @notice return the symbol of PoolsNFT
    function symbol() public pure override returns (string memory) {
        return "GRINDURUS_POOLS";
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

    /// @notice return true, if `_agent` is agent of `_ownerOf`. Else false
    /// @dev ownerOf is always self agent
    /// @dev `_ownerOf` is agent of `_ownerOf`. Approved `_agent` of `_ownerOf` is agent
    function isAgentOf(address _ownerOf, address _agent) public view override returns (bool) {
        if (balanceOf(_ownerOf) > 0) {
            if (_agent == address(grinderAI)) {
                return (_ownerOf == _agent || !_agentApprovals[_ownerOf][_agent]);
            } else {
                return (_ownerOf == _agent || _agentApprovals[_ownerOf][_agent]); 
            }
        } else {
            return false;
        }
    }

    /// @notice return true if `_depositor` is eligible to deposit to pool
    /// @param poolId pool id of pool in array `pools`
    /// @param _depositor address of account that makes deposit
    function isDepositorOf(uint256 poolId, address _depositor) public view override returns (bool) {
        return ownerOf(poolId) == _depositor || _depositorApprovals[poolId][ownerOf(poolId)][_depositor];
    }

    /// @notice gets pool ids owned by `poolOwner`
    /// @param poolOwner address of pool owner
    /// @return poolIdsOwnedByPoolOwner array of owner pool ids
    function getPoolIdsOf(
        address poolOwner
    )
        external
        view
        returns (uint256[] memory poolIdsOwnedByPoolOwner)
    {
        uint256 totalPoolIds = balanceOf(poolOwner);
        if (totalPoolIds == 0) {
            return new uint256[](0);
        }
        uint256 i = 0;
        poolIdsOwnedByPoolOwner = new uint256[](totalPoolIds);
        for (; i < totalPoolIds; ) {
            poolIdsOwnedByPoolOwner[i] = tokenOfOwnerByIndex(poolOwner, i);
            unchecked { ++i; }
        }
    }

    /// @notice get pool nft info by pool ids
    /// @param _poolIds array of poolIds
    function getPoolNFTInfosBy(uint256[] memory _poolIds) external view override returns (IPoolsNFTLens.PoolNFTInfo[] memory poolNFTInfos) {
        return poolsNFTLens.getPoolNFTInfosBy(_poolIds);
    }

    /// @notice get positions by pool ids
    /// @param _poolIds array of poolIds
    function getPositionsBy(uint256[] memory _poolIds) external view override returns (IPoolsNFTLens.Positions[] memory) {
        return poolsNFTLens.getPositionsBy(_poolIds);
    }

    /// @notice execute any transaction on target smart contract
    /// @dev callable only by owner
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    function execute(address target, uint256 value, bytes memory data) public payable override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        if (msg.value > 0) {
            bool success;
            if (address(grETH) == address(0)) {
                (success, ) = owner.call{value: msg.value}("");
            } else {
                (success, ) = address(grETH).call{value: msg.value}("");
            }
        }
    }
}
