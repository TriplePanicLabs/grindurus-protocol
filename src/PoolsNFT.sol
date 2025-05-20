// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IToken } from "src/interfaces/IToken.sol";
import { IPoolsNFT, IPoolsNFTLens, IGRETH, IGrinderAI } from "src/interfaces/IPoolsNFT.sol";
import { IStrategy, IURUS } from "src/interfaces/IStrategy.sol";
import { IStrategyFactory } from "src/interfaces/IStrategyFactory.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721, ERC721Enumerable, IERC165 } from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title GrindURUS Pools NFT
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice NFT that represets ownership of every grindurus strategy pools
contract PoolsNFT is IPoolsNFT, ERC721Enumerable {
    using SafeERC20 for IToken;

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    /// @dev royalty price shares
    RoyaltyPriceShares public royaltyPriceShares;

    /// @dev greth shares
    Shares public grethShares;

    /// @notice royalty shares
    Shares public royaltyShares;

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

    /// @dev poolId => pool strategy address
    mapping (uint256 poolId => address) public pools;

    /// @dev pool strategy address => poolId
    mapping (address pool => uint256) public poolIds;

    /// @notice store minter of pool for airdrop points
    /// @dev poolId => address of creator of NFT
    mapping (uint256 poolId => address) public agentOf;

    constructor() ERC721("GrindURUS Pools Collection", "GRINDURUS_POOLS") {
        totalPools = 0;
        pendingOwner = payable(address(0));
        owner = payable(msg.sender);

        royaltyPriceShares = RoyaltyPriceShares({
            auctionStartShare: 1_00,
            compensationShare: 101_00, 
            reserveShare: 1_00,
            poolOwnerShare: 5_00,
            ownerShare: 1_00
        });
        _checkRoyaltyPriceShares(royaltyPriceShares);

        grethShares = Shares({
            poolOwnerShare: 5_00,
            poolBuyerShare: 5_00,
            reserveShare: 80_00,
            grinderShare: 10_00
        });
        _checkShares(grethShares);

        royaltyShares = Shares({
            poolOwnerShare: 80_00,
            poolBuyerShare: 5_00,
            reserveShare: 5_00,
            grinderShare: 10_00
        });
        _checkShares(royaltyShares);
        //  profit = 1 USDT
        //  profit to pool owner = 1 * 80% = 0.8 USDT
        //  royalty = 1 * 20% = 0.2 USDT
        //      royalty to royaly receiver = 1 USDT * 5% = 0.05 USDT
        //      royalty to reserve = 1 USDT * 5% = 0.05 USDT
        //      royalty to grinder = 1 * 10% = 0.1 USDT
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

    /// @notice checks that msg.sender is grinderAI
    function _onlyGrinderAI() private view {
        if (msg.sender != address(grinderAI)) {
            revert NotGrinderAI();
        }
    }

    /// @notice checks that msg.sender is agent
    function _onlyAgentOf(uint256 poolId) private view {
        if (!isAgentOf(poolId, msg.sender)) {
            revert NotAgent();
        }
    }

    /// @notice checks royalty price shares
    function _checkRoyaltyPriceShares(RoyaltyPriceShares memory _royaltyPriceShares) private pure {
        if ( 
            _royaltyPriceShares.auctionStartShare + 
            _royaltyPriceShares.compensationShare +
            _royaltyPriceShares.reserveShare + 
            _royaltyPriceShares.poolOwnerShare + 
            _royaltyPriceShares.ownerShare <= DENOMINATOR
        ) {
            revert InvalidShares();
        }
    }

    /// @notice checks that royalty shares
    function _checkShares(Shares memory _shares) private pure {
        if (
            _shares.poolOwnerShare + 
            _shares.poolBuyerShare + 
            _shares.reserveShare + 
            _shares.grinderShare != DENOMINATOR
        ) {
            revert InvalidShares();
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

    /// @notice sets royalty price share to actors
    /// @dev callable only by owner
    function setRoyaltyPriceShares(RoyaltyPriceShares memory _royaltyPriceShares) external override {
        _onlyOwner();
        _checkRoyaltyPriceShares(_royaltyPriceShares);
        royaltyPriceShares = _royaltyPriceShares;
    }

    /// @notice sets greth shares
    /// @dev callable only by owner
    function setGRETHShares(Shares memory _grethShares) external override {
        _onlyOwner();
        _checkShares(_grethShares);
        grethShares = _grethShares;
    }

    /// @notice sets primary receiver royalty share
    /// @dev callable only by owner
    function setRoyaltyShares(Shares memory _royaltyShares) external override {
        _onlyOwner();
        _checkShares(_royaltyShares);
        royaltyShares = _royaltyShares;
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
    /// @param config URUS.Config structure. May be zeroify structure
    function mint(
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount,
        IURUS.Config memory config
    ) external override returns (uint256) {
        return mintTo(
            msg.sender,
            strategyId,
            baseToken,
            quoteToken,
            quoteTokenAmount,
            config
        );
    }

    /// @notice mints NFT with deployment of strategy
    /// @dev mints to `to`
    /// @param strategyId id of strategy implementation
    /// @param baseToken address of baseToken
    /// @param quoteToken address of quoteToken
    /// @param quoteTokenAmount amount of quoteToken to be deposited after mint
    /// @param config URUS.Config structure. May be zeroify structure
    function mintTo(
        address to,
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256 quoteTokenAmount,
        IURUS.Config memory config
    ) public override returns (uint256 poolId) {
        if (isStrategyStopped[strategyId]) {
            revert StrategyStopped();
        }
        poolId = _mintTo(to, strategyId, baseToken, quoteToken, config);
        _deposit(poolId, quoteTokenAmount);
        royaltyPrice[poolId] = (quoteTokenAmount * royaltyPriceShares.auctionStartShare) / DENOMINATOR;
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
        address quoteToken,
        IURUS.Config memory config
    ) internal returns (uint256 poolId) {
        poolId = totalPools;
        address pool = IStrategyFactory(strategyFactory[strategyId]).deploy(
            poolId,
            baseToken,
            quoteToken,
            config
        );
        agentOf[poolId] = msg.sender;
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

    /// @notice checks if `agent` is agent of poolId
    /// @param poolId id of pool in array `pools`
    /// @param agent address of agent
    function setAgentOf(uint256 poolId, address agent) public override {
        _onlyAgentOf(poolId);
        agentOf[poolId] = agent;
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
        _onlyAgentOf(poolId);
        return _deposit(poolId, quoteTokenAmount);
    }

    /// @dev make transfer from msg.sender, approve to pool, call deposit on pool
    function _deposit(
        uint256 poolId,
        uint256 quoteTokenAmount
    ) internal returns (uint256 depositedAmount) {
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        if (quoteTokenAmount > 0) {
            quoteToken.safeTransferFrom(msg.sender, address(this), quoteTokenAmount);
            quoteToken.forceApprove(address(pool), quoteTokenAmount);
            depositedAmount = pool.deposit(quoteTokenAmount);
            emit Deposit(
                poolId,
                address(pool),
                address(quoteToken),
                depositedAmount
            );
        }
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
        _onlyAgentOf(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        IToken baseToken = pool.baseToken();
        baseToken.safeTransferFrom(msg.sender, address(this), baseTokenAmount);
        baseToken.forceApprove(address(pool), baseTokenAmount);
        depositedBaseTokenAmount = pool.deposit2(baseTokenAmount, baseTokenPrice);
        emit Deposit2(
            poolId,
            address(pool), 
            address(baseToken), 
            baseTokenAmount, 
            baseTokenPrice
        );
    }

    /// @notice withdraw `quoteToken` from poolId to `to`
    /// @dev callcable only by owner of poolId.
    /// @dev withdrawable when distrubution is 100% quoteToken + 0% baseToken
    /// @param poolId pool id of pool in array `pools`
    /// @param to address of receiver of withdrawn funds
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return withdrawn amount of withdrawn quoteToken
    function withdraw(
        uint256 poolId,
        address to,
        uint256 quoteTokenAmount
    ) public override returns (uint256 withdrawn) {
        _onlyAgentOf(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        IToken quoteToken = pool.quoteToken();
        withdrawn = pool.withdraw(to, quoteTokenAmount);
        emit Withdraw(poolId, to, address(quoteToken), withdrawn);
    }

    /// @notice withdraw `quoteToken` from poolId to `to`
    /// @dev callcable only by owner of poolId.
    /// @dev withdrawable when distrubution is 100% quoteToken + 0% baseToken
    /// @param poolId pool id of pool in array `pools`
    /// @param to address of receiver of withdrawn funds
    /// @param baseTokenAmount amount of `quoteToken`
    /// @return withdrawn amount of withdrawn quoteToken
    function withdraw2(
        uint256 poolId,
        address to,
        uint256 baseTokenAmount
    ) public override returns (uint256 withdrawn) {
        _onlyAgentOf(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        IToken baseToken = pool.baseToken();
        withdrawn = pool.withdraw2(to, baseTokenAmount);
        emit Withdraw2(poolId, to, address(baseToken), withdrawn);
    }

    /// @notice exit from strategy and transfer ownership to royalty receiver
    /// @dev callable only by owner of poolId
    /// @param poolId pool id of pool in array `pools`
    function exit(
        uint256 poolId
    ) external override returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        _onlyAgentOf(poolId);
        IStrategy pool = IStrategy(pools[poolId]);
        (quoteTokenAmount, baseTokenAmount) = pool.exit();
        royaltyPrice[poolId] = 0;
        emit Exit(poolId, quoteTokenAmount, baseTokenAmount);
    }

    /// @notice checks capital on pool
    /// @param pool address of pool
    function _checkCapital(IStrategy pool) private view {
        if (pool.getActiveCapital() == 0) {
            revert NoCapital();
        }
    }

    /// @notice grind the pool with `poolId`
    /// @dev grETH == fee spend on iterate
    /// @param poolId pool id of pool in array `pools`
    function microOps(uint256 poolId) external override returns (bool isGrinded) {
        IStrategy pool = IStrategy(pools[poolId]);
        _checkCapital(pool);
        try pool.microOps() returns (bool iterated) {
            isGrinded = iterated;
        } catch {
            isGrinded = false;
        }
        if (isGrinded) {            
            _airdropGRETH(poolId);
        }
    }

    /// @notice grind the exact operation on the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @param op operation on strategy pool
    function microOp(uint256 poolId, uint8 op) external override returns (bool) {
        IStrategy pool = IStrategy(pools[poolId]);
        _checkCapital(pool);
        if (op == uint8(IGrinderAI.Op.LONG_BUY)) {
            pool.long_buy();
        } else if (op == uint8(IGrinderAI.Op.LONG_SELL)) {
            pool.long_sell();
        } else if (op == uint8(IGrinderAI.Op.HEDGE_SELL)) {
            pool.hedge_sell();
        } else if (op == uint8(IGrinderAI.Op.HEDGE_REBUY)) {
            pool.hedge_rebuy();
        } else {
            revert NotMicroOp();
        }
        _airdropGRETH(poolId);
        return true;
    }

    /// @notice airdrop greth
    /// @dev for executing agent related operations
    /// @param poolId pool id of pool in array `pools`
    function airdropGRETH(uint256 poolId) public override {
        _onlyGrinderAI();
        _airdropGRETH(poolId);
    }

    /// @notice airdrop for executing micro op
    function _airdropGRETH(uint256 poolId) internal {
        uint256 grethAmount;
        try grinderAI.ratePerGRAI(address(0)) returns (uint256 _rate) {
            grethAmount = _rate;
        } catch {
            grethAmount = 0.0001 ether;
        }
        (address[] memory actors, uint256[] memory _grethShares) = calcGRETHShares(
            poolId,
            grethAmount
        );
        try grETH.mint(actors, _grethShares) {} catch {}
    }

    /// @notice transfert poolId from `msg.sender` to `to`
    /// @param to address of pool receiver
    /// @param poolId pool id of pool in array `pools`
    function transfer(address to, uint256 poolId) public {
        if (agentOf[poolId] != ownerOf(poolId)) {
            revert HasAgent();
        }
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
        royaltyAmount = (salePrice * (DENOMINATOR - royaltyShares.poolOwnerShare)) / DENOMINATOR;
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
            compensationShare = (_royaltyPrice * royaltyPriceShares.compensationShare) / _denominator;
            poolOwnerShare = (_royaltyPrice * royaltyPriceShares.poolOwnerShare) / _denominator;
            reserveShare = (_royaltyPrice * royaltyPriceShares.reserveShare) / _denominator;
            ownerShare = (_royaltyPrice * royaltyPriceShares.ownerShare) / _denominator;
            oldRoyaltyPrice = _royaltyPrice;
            newRoyaltyPrice = compensationShare + poolOwnerShare + reserveShare + ownerShare;
        } else {
            newRoyaltyPrice = IStrategy(pools[poolId]).getActiveCapital() * royaltyPriceShares.auctionStartShare / _denominator;
        }
    }

    /// @notice calculates shares of grETH for actors
    /// @param poolId pool id of pool in array `pools`
    /// @param grethAmount amount of grETH
    function calcGRETHShares(
        uint256 poolId,
        uint256 grethAmount
    ) public view override returns (address[] memory receivers, uint256[] memory _grethShares)
    {
        receivers = new address[](4);
        _grethShares = new uint256[](4);
        receivers[0] = ownerOf(poolId); // poolOwner
        receivers[1] = getRoyaltyReceiver(poolId); // royalty receiver
        receivers[2] = address(grETH) != address(0) ? address(grETH) : owner; // grETH
        try grinderAI.grinder() returns (address payable _grinder) {
            receivers[3] = (_grinder != payable(0)) ? _grinder : owner;
        } catch {
            receivers[3] = owner;
        }
        _grethShares[0] = (grethAmount * grethShares.poolOwnerShare) / DENOMINATOR;
        _grethShares[1] = (grethAmount * grethShares.poolBuyerShare) / DENOMINATOR;
        _grethShares[2] = (grethAmount * grethShares.reserveShare) / DENOMINATOR;
        _grethShares[3] = grethAmount - (_grethShares[0] + _grethShares[1] + _grethShares[2]);
    }

    /// @notice calculates royalty shares
    /// @param poolId pool id of pool in array `pools`
    /// @param profit amount of token to be distributed
    /// @dev returns array of receivers and amounts
    function calcRoyaltyShares(
        uint256 poolId,
        uint256 profit
    ) public view override returns (address[] memory receivers, uint256[] memory amounts)
    {
        receivers = new address[](4);
        amounts = new uint256[](4);
        receivers[0] = ownerOf(poolId); // pool owner
        receivers[1] = getRoyaltyReceiver(poolId); // royalty receiver
        receivers[2] = (address(grETH) != address(0)) ? address(grETH) : owner; // reserve
        try grinderAI.grinder() returns (address payable _grinder) {
            receivers[3] = (_grinder != payable(0)) ? _grinder : owner;
        } catch {
            receivers[3] = owner;
        }
        amounts[0] = (profit * royaltyShares.poolOwnerShare) / DENOMINATOR;
        amounts[1] = (profit * royaltyShares.poolBuyerShare) / DENOMINATOR;
        amounts[2] = (profit * royaltyShares.reserveShare) / DENOMINATOR;
        amounts[3] = profit - (amounts[0] + amounts[1] + amounts[2]);
    }

    /// @notice return base URI
    /// @dev base URI holds on poolsNFTLens
    function baseURI() public view override returns (string memory) {
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

    /// @notice get zero config
    function getZeroConfig() external view returns (IURUS.Config memory) {
        return poolsNFTLens.getZeroConfig();
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
    function isAgentOf(uint256 poolId, address account) public view override returns (bool) {
        return agentOf[poolId] == account || account == ownerOf(poolId);
    }

    /// @notice gets pool ids owned by `poolOwner`
    /// @param poolOwner address of pool owner
    /// @return poolIdsOf array of owner pool ids
    function getPoolIdsOf(
        address poolOwner
    ) external view returns (uint256[] memory poolIdsOf) {
        uint256 totalPoolIds = balanceOf(poolOwner);
        if (totalPoolIds == 0) {
            return new uint256[](0);
        }
        poolIdsOf = new uint256[](totalPoolIds);
        for (uint256 i = 0; i < totalPoolIds; ) {
            poolIdsOf[i] = tokenOfOwnerByIndex(poolOwner, i);
            unchecked { ++i; }
        }
    }

    /// @notice get pool nft info by pool ids
    /// @param _poolIds array of poolIds
    function getPoolInfosBy(uint256[] memory _poolIds) external view override returns (IPoolsNFTLens.PoolInfo[] memory poolInfos) {
        return poolsNFTLens.getPoolInfosBy(_poolIds);
    }

    /// @notice get positions by pool ids
    /// @param _poolIds array of poolIds
    function getPositionsBy(uint256[] memory _poolIds) external view override returns (IPoolsNFTLens.Positions[] memory) {
        return poolsNFTLens.getPositionsBy(_poolIds);
    }

    /// @notice returns wrapped eth address
    function weth() public view override returns (address) {
        return address(grETH.weth());
    }

    /// @notice returns royalty price shares
    function getRoyaltyPriceShares() external view returns (RoyaltyPriceShares memory) {
        return royaltyPriceShares;
    }

    /// @notice returns greth shares
    function getGRETHShares() external view returns(Shares memory) {
        return grethShares;
    }

    /// @notice returns royalty shares
    function getRoyaltyShares() external view returns (Shares memory) {
        return royaltyShares;
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
