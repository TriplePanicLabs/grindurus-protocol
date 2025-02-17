// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IGRETH} from "src/interfaces/IGRETH.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IStrategy, IURUS} from "src/interfaces/IStrategy.sol";
import {IPoolsNFTImage} from "src/interfaces/IPoolsNFTImage.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IStrategyFactory} from "src/interfaces/IStrategyFactory.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Base64} from "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ERC721, ERC721Enumerable, IERC165} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title GrindURUS Pools NFT
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice NFT that represets ownership of every grindurus strategy pools
contract PoolsNFT is IPoolsNFT, ERC721Enumerable, ReentrancyGuard {
    using SafeERC20 for IToken;
    using Base64 for bytes;
    using Strings for uint256;

    //// CONTSTANTS ////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    //// ROYALTY PRICE SHARES //////////////////////////////////////////////////////////////////////////////////////////////////

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

    /// @notice royalty share of last grinder
    /// @dev example: royaltyGrinderShareNumerator == 5_00 == 5%
    uint16 public royaltyGrinderShareNumerator;

    //// PoolsNFT OWNERSHIP DATA ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev address of pending owner
    address payable public pendingOwner;

    /// @dev address of grindurus protocol owner. For DAO
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

    /// @notice address of poolsNFTImage
    IPoolsNFTImage public poolsNFTImage;

    /// @notice reserve for accumulation of percent of strategy profits
    /// @dev grETH token address
    IGRETH public grETH;

    /// @dev strategiest address => is strategiest
    mapping (address strategiest => bool) public isStrategiest;

    /// @dev strategyId => address of grindurus pool strategy implementation
    mapping (uint16 strategyId => address) public strategyFactory;

    /// @dev strategyId => is strategy stoped. true - stopped. false - not stopped
    /// @dev by default strategy is not stopped
    mapping (uint16 strategyId => bool) public isStrategyStopped;

    /// @dev poolId => royalty receiver
    mapping (uint256 poolId => address) public royaltyReceiver;

    /// @dev poolId => royalty price
    mapping (uint256 poolId => uint256) public royaltyPrice;

    /// @notice store minter of pool for airdrop points
    /// @dev poolId => address of creator of NFT
    mapping (uint256 poolId => address) public minter;

    /// @dev poolId => pool strategy address
    mapping (uint256 poolId => address) public pools;

    /// @dev pool strategy address => poolId
    mapping (address pool => uint256) public poolIds;

    /// @dev poolId => token address => deposit amount
    mapping (uint256 poolId => mapping (address token => uint256)) public deposited;

    /// @dev token address => amount of deposit in pool
    mapping (address token => uint256) public totalDeposited;

    /// @dev token address => minimum amount to deposit
    /// @dev if minDeposit == 0, that no limit for minimum deposit
    mapping (address token => uint256) public minDeposit;

    /// @dev token address => token cap
    /// @dev if cap == 0, than cap is unlimited
    mapping (address token => uint256) public tokenCap;

    /// @dev owner of address => agent address => is agent of `_ownerOf`
    /// @dev true - is agent. False - is not agent
    mapping (address _ownerOf => mapping (address _agent => bool)) internal _agentApprovals;

    /// @dev pool id => owner of pool => depositor => is approved. true - approved, false - not approved
    /// @dev true - is eligible depositor. false - is not eligible depositor
    mapping (uint256 poolId => mapping (address _ownerOf => mapping(address depositor => bool))) internal _depositorApprovals;

    constructor() ERC721("GRINDURUS Pools Collection", "GRINDURUS_POOLS") {
        baseURI = "https://raw.githubusercontent.com/TriplePanicLabs/grindurus-poolsnft-data/refs/heads/main/arbitrum/";
        totalPools = 0;
        pendingOwner = payable(address(0));
        owner = payable(msg.sender);
        lastGrinder = payable(msg.sender);
        isStrategiest[msg.sender] = true;

        royaltyPriceCompensationShareNumerator = 101_00; // 101%
        royaltyPriceReserveShareNumerator = 1_00; // 1%
        royaltyPricePoolOwnerShareNumerator = 5_00; // 5%
        royaltyPriceGrinderShareNumerator = 1_00; // 1%
        // total royalty price = 101% + 1% + 5% + 1% = 108% > 100%
        require(royaltyPriceCompensationShareNumerator + royaltyPriceReserveShareNumerator + royaltyPricePoolOwnerShareNumerator + royaltyPriceGrinderShareNumerator > DENOMINATOR);

        grethGrinderShareNumerator = 80_00; // 80%
        grethReserveShareNumerator = 15_00; // 15%
        grethPoolOwnerShareNumerator = 2_00; // 2%
        grethRoyaltyReceiverShareNumerator = 3_00; // 3%;
        // total greth share = 80% + 15% + 2% + 3% = 100%
        require(grethGrinderShareNumerator + grethReserveShareNumerator + grethPoolOwnerShareNumerator + grethRoyaltyReceiverShareNumerator == DENOMINATOR);
        
        // poolOwnerShareNumerator + royaltyReserveShareNumerator + royaltyReceiverShareNumerator + royaltyGrinderShareNumerator == DENOMINATOR
        royaltyNumerator = 20_00; // 20%
        poolOwnerShareNumerator = 80_00; // 80%
        royaltyReceiverShareNumerator = 10_00; // 10%
        royaltyReserveShareNumerator = 5_00; // 5%
        royaltyGrinderShareNumerator = 5_00; // 5%
        // total royalty + owner share = 20% + 80% = 100%
        // total royalty share = 80% + 10% + 5% + 5% = 100%
        require(royaltyNumerator + poolOwnerShareNumerator == DENOMINATOR);
        require(poolOwnerShareNumerator + royaltyReceiverShareNumerator + royaltyReserveShareNumerator + royaltyGrinderShareNumerator == DENOMINATOR);
        //  profit = 1 USDT
        //  profit to pool owner = 1 * (80%) = 0.8 USDT
        //  royalty = 1 * 20% = 0.2 USDT
        //      royalty to reserve  = 0.2 * 4% = 0.008 USDT
        //      royalty to royaly receiver = 0.2 * 15% = 0.03 USDT
        //      royalty grinder = 0.2 * 1% = 0.002 USDT
    }

    /// @notice sets grETH token
    /// @dev callable only by owner
    function init(address _grETH) external override {
        _onlyOwner();
        require(address(grETH) == address(0));
        grETH = IGRETH(_grETH);
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    /// @notice checks that msg.sender is owner of pool id
    function _onlyOwnerOf(uint256 poolId) private view {
        if (msg.sender != ownerOf(poolId)) {
            revert NotOwnerOf();
        }
    }

    /// @notice checks that msg.sender is strategiest
    function _onlyStrategiest() private view {
        if (!isStrategiest[msg.sender]) {
            revert NotStrategiest();
        }
    }

    /////// ONLY STRATEGIEST FUNCTIONS

    /// @notice set stop on strategy with `strategyId`
    /// @param strategyId id of strategy
    /// @param _isStrategyStopped is strategy stopped. true - stopped. false - not stopped
    function setStrategyStopped(uint16 strategyId, bool _isStrategyStopped) public override {
        _onlyStrategiest();
        isStrategyStopped[strategyId] = _isStrategyStopped;
    }

    /////// ONLY OWNER FUNCTIONS

    /// @notice sets strategiest
    /// @param strategiest address of strategiest
    /// @param _isStrategiest true if strategiest, false if not strategiest
    function setStrategiest(address strategiest, bool _isStrategiest) public override {
        _onlyOwner();
        isStrategiest[strategiest] = _isStrategiest;
        emit SetStrategiest(strategiest, _isStrategiest);
    }

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) external override {
        _onlyOwner();
        baseURI = _baseURI;
        emit SetBaseURI(_baseURI);
    }

    /// @notice sets pools NFT Image
    /// @param _poolsNFTImage address of poolsNFTImage
    function setPoolsNFTImage(address _poolsNFTImage) external override {
        _onlyOwner();
        poolsNFTImage = IPoolsNFTImage(_poolsNFTImage);
        emit SetPoolsNFTImage(_poolsNFTImage);
    }

    /// @notice sets minimum deposit
    /// @param token address of token
    /// @param _minDeposit minimum amount of deposit
    function setMinDeposit(address token, uint256 _minDeposit) external override {
        _onlyOwner();
        minDeposit[token] = _minDeposit;
        emit SetMinDeposit(token, _minDeposit);
    }

    /// @notice sets cap tvl
    /// @dev if _capTVL==0, than no cap for asset
    /// @param token address of token
    /// @param _tokenCap maximum amount of token
    function setTokenCap(address token, uint256 _tokenCap) external override {
        _onlyOwner();
        tokenCap[token] = _tokenCap;
        emit SetTokenCap(token, _tokenCap);
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
        emit SetRoyaltyPriceShares(        
            _royaltyPriceCompensationShareNumerator,
            _royaltyPriceReserveShareNumerator,
            _royaltyPricePoolOwnerShareNumerator,
            _royaltyPriceGrinderShareNumerator
        );
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
        emit SetGRETHShares(        
            _grethGrinderShareNumerator,
            _grethReserveShareNumerator,
            _grethPoolOwnerShareNumerator,
            _grethRoyaltyReceiverShareNumerator
        );
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
        poolOwnerShareNumerator = _poolOwnerRoyaltyShareNumerator;
        royaltyReceiverShareNumerator = _royaltyReceiverShareNumerator;
        royaltyReserveShareNumerator = _royaltyReserveShareNumerator;
        royaltyGrinderShareNumerator = _royaltyGrinderShareNumerator;
        emit SetRoyaltyShares(
            _poolOwnerRoyaltyShareNumerator,
            _royaltyReceiverShareNumerator,
            _royaltyReserveShareNumerator,
            _royaltyGrinderShareNumerator
        );
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
            revert NotOwnerOrPending();
        }
    }

    /// @notice set factrory strategy
    /// @dev callable only by strategiest
    function setStrategyFactory(address _strategyFactory) external override {
        _onlyStrategiest();
        uint16 strategyId = IStrategyFactory(_strategyFactory).strategyId();
        strategyFactory[strategyId] = _strategyFactory;
        isStrategyStopped[strategyId] = false;
        emit SetFactoryStrategy(strategyId, _strategyFactory);
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
        address quoteToken,
        address baseToken,
        uint256 quoteTokenAmount
    ) external override returns (uint256 poolId) {
        poolId = mintTo(
            msg.sender,
            strategyId,
            quoteToken,
            baseToken,
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
        address quoteToken,
        address baseToken,
        uint256 quoteTokenAmount
    ) public override returns (uint256 poolId) {
        if (isStrategyStopped[strategyId]) {
            revert StrategyStopped();
        }
        poolId = totalPools;
        address pool = IStrategyFactory(strategyFactory[strategyId]).deploy(
            poolId,
            quoteToken,
            baseToken
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
        _deposit(
            poolId,
            quoteTokenAmount
        );
    }

    /// @notice set royalty price. Sets once
    /// @dev callable only by owner of `poolId`
    /// @param poolId id of pool
    /// @param _royaltyPrice amount of ETH
    function setRoyaltyPrice(uint256 poolId, uint256 _royaltyPrice) external override {
        _onlyOwnerOf(poolId);
        require(royaltyPrice[poolId] == 0 && _royaltyPrice > 0);
        royaltyPrice[poolId] = _royaltyPrice;
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
    ) external override returns (uint256 depositedAmount) {
        if (!isDepositorOf(poolId, msg.sender)) {
            revert NotDepositor();
        }
        depositedAmount = _deposit(poolId, quoteTokenAmount);
    }

    /// @dev make transfer from msg.sender, approve to pool, call deposit on pool
    function _deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) internal returns (uint256 depositedAmount) {
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        _checkMinDeposit(address(quoteToken), quoteTokenAmount);
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
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
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
        IStrategy pool = IStrategy(pools[poolId]);
        (quoteTokenAmount, baseTokenAmount) = pool.exit();
        address poolNFTRecipient = getRoyaltyReceiver(poolId);
        if (poolNFTRecipient == ownerOf(poolId)) {
            poolNFTRecipient = owner; // tranfer to protocol owner
        }
        transferFrom(ownerOf(poolId), poolNFTRecipient, poolId);
        IToken quoteToken = pool.quoteToken();
        _decreaseTotalDeposited(address(quoteToken), deposited[poolId][address(quoteToken)]);
        deposited[poolId][address(quoteToken)] = 0;
        emit Exit(poolId, quoteTokenAmount, baseTokenAmount);
    }

    /// @notice checks min deposit
    function _checkMinDeposit(address quoteToken, uint256 depositAmount) private view {
        if (depositAmount < minDeposit[quoteToken]) {
            revert InsufficientDeposit();
        }
    }

    /// @notice checks TVL of quoteToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quote token
    function _checkCap(address quoteToken, uint256 quoteTokenAmount) private view {
        if ((tokenCap[quoteToken] > 0) && (tokenCap[quoteToken] + quoteTokenAmount > tokenCap[quoteToken])) {
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

    /// @notice approve agent to msg.sender
    /// @param _agent address of agent
    function setAgent(address _agent, bool _agentApproval) external override {
        _agentApprovals[msg.sender][_agent] = _agentApproval;
    }

    /// @notice rebalance the pools with poolIds `poolId0` and `poolId1`
    /// @dev only owner or AI-agent of pools can rebalance with equal strategy id
    /// @param poolId0 pool id of pool to rebalance
    /// @param poolId1 pool id of pool to rebalance
    function rebalance(
        uint256 poolId0,
        uint256 poolId1
    ) external override {
        if (ownerOf(poolId0) != ownerOf(poolId1)) {
            revert DifferentOwnersOfPools();
        }
        if (!isAgentOf(ownerOf(poolId0), msg.sender)) {
            revert NotAgent();
        }
        IStrategy pool0 = IStrategy(pools[poolId0]);
        IStrategy pool1 = IStrategy(pools[poolId1]);
        IToken pool0BaseToken = pool0.baseToken();
        IToken pool1BaseToken = pool1.baseToken();
        if (address(pool0.quoteToken()) != address(pool1.quoteToken())) {
            revert DifferentQuoteTokens();
        }
        if (address(pool0BaseToken) != address(pool1BaseToken)) {
            revert DifferentBaseTokens();
        }

        (uint256 baseTokenAmount0, uint256 price0) = pool0.beforeRebalance();
        pool0BaseToken.safeTransferFrom(address(pool0), address(this), baseTokenAmount0);
        (uint256 baseTokenAmount1, uint256 price1) = pool1.beforeRebalance();
        pool1BaseToken.safeTransferFrom(address(pool1), address(this), baseTokenAmount1);

        // second step: rebalance
        uint256 totalBaseTokenAmount = baseTokenAmount0 + baseTokenAmount1;
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
        emit Rebalance(
            poolId0,
            poolId1
        );
    }

    /// @notice grind the pool with `poolId`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    function grind(uint256 poolId) external override returns (bool isGrinded) {
        isGrinded = grindTo(poolId, msg.sender);
    }

    /// @notice grind the pool with `poolId` and grinder is `to`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    /// @param grinder address of grinder, that will receive grind reward
    function grindTo(uint256 poolId, address grinder) public override returns (bool isGrinded) {
        uint256 gasStart = gasleft();
        IStrategy pool = IStrategy(pools[poolId]);
        try pool.iterate() returns (bool iterated) {
            isGrinded = iterated;
        } catch {
            isGrinded = false;
        }
        if (isGrinded) {
            uint256 grethReward = (gasStart - gasleft()) * tx.gasprice; // amount of native token used for grind 
            _reward(poolId, grethReward, grinder);
        }
        lastGrinder = payable(grinder);
        emit Grind(poolId, grinder, isGrinded);
    }

    /// @notice grind the exact operation on the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @param op operation on strategy pool
    function grindOp(uint256 poolId, IURUS.Op op) public returns (bool isGrinded) {
        isGrinded = grindOpTo(poolId, op, msg.sender);
    }

    /// @notice grind the exact operation on the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @param op operation on strategy pool
    /// @param grinder address of grinder, that will receive grind reward
    function grindOpTo(uint256 poolId, IURUS.Op op, address grinder) public override returns (bool isGrinded) {
        uint256 gasStart = gasleft();
        IStrategy pool = IStrategy(pools[poolId]);
        if (op == IURUS.Op.LONG_BUY) {
            try pool.long_buy() {
                isGrinded = true;
            }
            catch {}
        } else if (op == IURUS.Op.LONG_SELL) {
            try pool.long_sell() {
                isGrinded = true;
            }
            catch {}
        } else if (op == IURUS.Op.HEDGE_SELL) {
            try pool.hedge_sell() {
                isGrinded = true;
            }
            catch {}
        } else if (op == IURUS.Op.HEDGE_REBUY) {
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
        }
        lastGrinder = payable(grinder);
        emit Grind(poolId, grinder, isGrinded);
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
        if (newRoyaltyPrice == 0) {
            revert ZeroNewRoyaltyPrice();
        }
        if (msg.value < newRoyaltyPrice) {
            revert InsufficientRoyaltyPrice();
        }
        address payable oldRoyaltyReceiver = payable(getRoyaltyReceiver(poolId));
        // instantiate new royalty receiver
        royaltyReceiver[poolId] = to;
        royaltyPrice[poolId] = newRoyaltyPrice; // newRoyaltyPrice always increase!

        if (compensationShare > 0) {
            _sendETH(oldRoyaltyReceiver, compensationShare);
            royaltyPricePaid += compensationShare;
        }
        if (poolOwnerShare > 0) {
            _sendETH(payable(ownerOf(poolId)), poolOwnerShare);
            royaltyPricePaid += poolOwnerShare;
        }
        if (reserveShare > 0) {
            _sendETH(payable(address(grETH)), reserveShare);
            royaltyPricePaid += reserveShare;
        }
        if (lastGrinderShare > 0) {
            _sendETH(lastGrinder, lastGrinderShare);
            royaltyPricePaid += lastGrinderShare;
        }
        refund = msg.value - royaltyPricePaid;
        if (refund > 0) {
            _sendETH(payable(msg.sender), refund);
        }
        emit BuyRoyalty(poolId, to, royaltyPricePaid);
    }

    /// @notice sends ETH
    /// @param receiver address of receiver
    /// @param amount amount of ETH
    function _sendETH(address payable receiver, uint256 amount) internal {
        bool success;
        (success, ) = receiver.call{value: amount}("");
        if (!success) {
            (success, ) = owner.call{value: amount}("");
        }
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
        receivers[2] = address(grETH) != address(0) ? address(grETH) : owner;
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
        compensationShare = (_royaltyPrice * royaltyPriceCompensationShareNumerator) / _denominator;
        poolOwnerShare = (_royaltyPrice * royaltyPricePoolOwnerShareNumerator) / _denominator;
        reserveShare = (_royaltyPrice * royaltyPriceReserveShareNumerator) / _denominator;
        lastGrinderShare = (_royaltyPrice * royaltyPriceGrinderShareNumerator) / _denominator;
        oldRoyaltyPrice = _royaltyPrice;
        newRoyaltyPrice = compensationShare + poolOwnerShare + reserveShare + lastGrinderShare;
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

        grethShares[0] = (grethReward * grethPoolOwnerShareNumerator) / denominator; // (grethReward * (denominator - poolOwnerShareNumerator)) / denominator;
        grethShares[1] = (grethReward * grethReserveShareNumerator) / denominator;
        grethShares[2] = (grethReward * grethRoyaltyReceiverShareNumerator) / denominator;
        grethShares[3] = grethReward - (grethShares[0] + grethShares[1] + grethShares[2]);
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
        if (address(poolsNFTImage) == address(0)) {
            // https://raw.githubusercontent.com/TriplePanicLabs/GrindURUS-PoolsNFTsData/refs/heads/main/arbitrum/{poolId}.json
            string memory path = string.concat(baseURI, poolId.toString());
            uri = string.concat(path, ".json");
        } else {
            uri = poolsNFTImage.URI(poolId);
        }
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
    /// @dev `_ownerOf` is agent of `_ownerOf`. Approved `_agent` of `_ownerOf` is agent
    function isAgentOf(address _ownerOf, address _agent) public view override returns (bool) {
        return balanceOf(_ownerOf) > 0 ? (_ownerOf == _agent || _agentApprovals[_ownerOf][_agent]) : false;
    }

    /// @notice return true if `_depositor` is eligible to deposit to pool
    /// @param poolId pool id of pool in array `pools`
    /// @param _depositor address of account that makes deposit
    function isDepositorOf(uint256 poolId, address _depositor) public view override returns (bool) {
        return ownerOf(poolId) == _depositor || _depositorApprovals[poolId][ownerOf(poolId)][_depositor];
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
            unchecked { ++i; }
        }
        return (totalPoolIds, poolIdsOwnedByPoolOwner);
    }

    /// @notice pagination for table on dashboard with poolNFT info
    /// @param fromPoolId pool id from
    /// @param toPoolId pool id to
    function getPoolNFTInfos(
        uint256 fromPoolId,
        uint256 toPoolId
    ) external view returns (PoolNFTInfo[] memory poolInfos) {
        require(fromPoolId <= toPoolId);
        poolInfos = new PoolNFTInfo[](toPoolId - fromPoolId + 1);
        uint256 poolId = fromPoolId;
        uint256 poolInfosId = 0;
        for (; poolId <= toPoolId; ) {
            poolInfos[poolInfosId] = _formPoolInfo(poolId);
            unchecked {
                ++poolId;
                ++poolInfosId;
            }
        }
    }

    /// @notice get pool nft info by pool ids
    /// @param _poolIds array of poolIds
    function getPoolNFTInfosBy(uint256[] memory _poolIds) external view override returns (PoolNFTInfo[] memory poolInfos) {
        uint256 poolIdsLen = _poolIds.length;
        poolInfos = new PoolNFTInfo[](poolIdsLen);
        uint256 poolInfosId = 0;
        for (; poolInfosId < poolIdsLen; ) {
            poolInfos[poolInfosId] = _formPoolInfo(_poolIds[poolInfosId]);
            unchecked {
                ++poolInfosId;
            }
        }
    }

    /// @notice forms pool info
    /// @param poolId id of pool
    function _formPoolInfo(uint256 poolId) private view returns (PoolNFTInfo memory poolInfo) {
        IStrategy pool = IStrategy(pools[poolId]);
        (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        ) = pool.getTotalProfits();
        (uint256 APRNumerator, uint256 APRDenominator) = pool.APR();
        poolInfo = PoolNFTInfo({
            poolId: poolId,
            config: _formConfig(poolId),
            strategyId: pool.strategyId(),
            quoteToken: address(pool.getQuoteToken()),
            baseToken: address(pool.getBaseToken()),
            quoteTokenSymbol: pool.getQuoteToken().symbol(),
            baseTokenSymbol: pool.getBaseToken().symbol(),
            quoteTokenAmount: pool.getQuoteTokenAmount(),
            baseTokenAmount: pool.getBaseTokenAmount(),
            quoteTokenYieldProfit: quoteTokenYieldProfit,
            baseTokenYieldProfit: baseTokenYieldProfit,
            quoteTokenTradeProfit: quoteTokenTradeProfit,
            baseTokenTradeProfit: baseTokenTradeProfit,
            APRNumerator: APRNumerator,
            APRDenominator: APRDenominator,
            activeCapital: pool.getActiveCapital(),
            royaltyPrice: royaltyPrice[poolId]
        });
    }

    /// @notice forms config structure for `getPoolNFTInfos`
    /// @param poolId id of pool
    function _formConfig(uint256 poolId) private view returns (IURUS.Config memory) {
        (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 extraCoef,
            uint256 priceVolatilityPercent,
            uint256 initHedgeSellPercent,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) = getConfig(poolId);
        return IURUS.Config({
            longNumberMax: longNumberMax,
            hedgeNumberMax: hedgeNumberMax,
            extraCoef: extraCoef,
            priceVolatilityPercent: priceVolatilityPercent,
            initHedgeSellPercent: initHedgeSellPercent,
            returnPercentLongSell: returnPercentLongSell,
            returnPercentHedgeSell: returnPercentHedgeSell,
            returnPercentHedgeRebuy: returnPercentHedgeRebuy
        });

    }

    /// @notice returns config
    /// @param poolId id of pool
    function getConfig(uint256 poolId) public view override 
        returns (
            uint8 longNumberMax,
            uint8 hedgeNumberMax,
            uint256 extraCoef,
            uint256 priceVolatility,
            uint256 initHedgeSellPercent,
            uint256 returnPercentLongSell,
            uint256 returnPercentHedgeSell,
            uint256 returnPercentHedgeRebuy
        ) {
        (
            longNumberMax,
            hedgeNumberMax,
            extraCoef,
            priceVolatility,
            initHedgeSellPercent,
            returnPercentLongSell,
            returnPercentHedgeSell,
            returnPercentHedgeRebuy
        ) = IStrategy(pools[poolId]).getConfig();
    }

    /// @notice returns long position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getLong(uint256 poolId) public view override
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
        ) = IStrategy(pools[poolId]).getLong();
    }

    /// @notice returns hedge position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getHedge(uint256 poolId) public view override
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
        ) = IStrategy(pools[poolId]).getHedge();
    }

    /// @notice returns positions of strategy
    function getPositions(uint256 poolId) public view override returns(IURUS.Position memory long, IURUS.Position memory hedge) {
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
        ) = getLong(poolId);
        long = IURUS.Position({
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
        ) = getHedge(poolId);
        hedge = IURUS.Position({
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

    /// @notice execute any transaction on target smart contract
    /// @dev callable only by owner
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    function execute(address target, uint256 value, bytes memory data) public override {
        _onlyOwner();
        (bool success,) = target.call{value: value}(data);
        success;
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
