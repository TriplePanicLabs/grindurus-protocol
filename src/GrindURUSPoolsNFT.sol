// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IGrindToken} from "src/interfaces/IGrindToken.sol";
import {IGrindURUSPoolsNFT} from "src/interfaces/IGrindURUSPoolsNFT.sol";
import {IGrindURUSPoolStrategy} from "src/interfaces/IGrindURUSPoolStrategy.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IFactoryGrindURUSPoolStrategy} from "src/interfaces/IFactoryGrindURUSPoolStrategy.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {
    ERC721,
    ERC721Enumerable,
    IERC165
} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @title GrindURUSPoolsNFT
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice NFT that represets ownership of every grindurus strategy pools
contract GrindURUSPoolsNFT is IGrindURUSPoolsNFT, ERC721Enumerable, ReentrancyGuard {
    using SafeERC20 for IToken;
    using Strings for uint256;

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    /// @notice maximum royalty numerator.
    /// @dev this value of max royalty is 20%
    /// Dont panic, the actural royalty numerator stores in `royaltyNumerator`
    uint16 public constant MAX_ROYALTY_NUMERATOR = 20_00;

    //// BUY ROYALTY PRICE SHARES

    /// @dev numerator of royalty price compensation share
    uint16 public royaltyPriceCompensationShareNumerator;

    /// @dev numerator of royalty price primary receiver share
    uint16 public royaltyPricePrimaryReceiverShareNumerator;

    /// @dev numerator of royalty price pool owner share
    uint16 public royaltyPricePoolOwnerShareNumerator;

    /// @dev numerator of royalty price last grinder share
    uint16 public royaltyPriceLastGrinderShareNumerator;

    //// ROYALTY DISTRIBUTION

    /// @notice the init royalty price numerator
    /// @dev converts initial `quoteToken` to `feeToken` and multiply to numerator and divide by DENOMINATOR
    uint16 public initRoyaltyPriceNumerator;

    /// @notice the numerator of royalty
    /// @dev this royalty is ditributed to actor shares
    uint16 public royaltyNumerator;

    /// @notice royalty share of primary receiver
    uint16 public primaryReceiverRoyaltyShareNumerator;

    /// @notice royalty share of receiver
    uint16 public receiverRoyaltyShareNumerator;

    /// @notice royalty share of last grinder
    uint16 public lastGrinderRoyaltyShareNumerator;

    //// NFT OWNERSHIP DATA

    /// @dev address of pending owner
    /// It may be you accepting the ownership, but you dont have 100_000 ETH
    address payable public pendingOwner;

    /// @dev address of pending primary receiver royalty
    address payable public pendingPrimaryReceiverRoyalty;

    /// @dev address of grindurus protocol owner
    address payable public owner;

    /// @notice address, that receives the primary royalty
    /// @dev address of main royalty receiver
    address payable public primaryReceiverRoyalty;

    /// @notice address,that last called grind()
    /// @dev address of last grinder
    /// The last of magician blyat
    address payable public lastGrinder;

    //// POOLS DATA

    /// @notice base URI for this collection
    string public baseURI;

    /// @notice total amount of positions
    uint256 public totalPools;

    /// @dev grind token
    IGrindToken public grindToken;

    /// @dev strategyId => address of grindurus pool strategy implementation
    mapping(uint16 strategyId => IFactoryGrindURUSPoolStrategy) public factoryStrategy;

    /// @dev strategyId => is strategy enable
    mapping(uint16 strategyId => bool) public strategyEnable;

    /// @dev address of strategiest => is strategiest
    mapping(address strategiest => bool) public isStrategiest;

    /// @dev poolId => royalty receiver
    mapping(uint256 poolId => address) public royaltyReceiver;

    /// @dev poolId => royalty price
    mapping(uint256 poolId => uint256) public royaltyPrice;

    /// @dev poolId => pool strategy address
    mapping(uint256 poolId => address) public pools;

    /// @dev pool strategy address => poolId
    mapping(address pool => uint256) public poolIds;

    constructor() ERC721("GRINDURUS Strategy Pools Collection", "GRINDURUS_POOLS") {
        baseURI = "";
        totalPools = 0;
        pendingOwner = payable(address(0));
        pendingPrimaryReceiverRoyalty = payable(address(0));
        owner = payable(msg.sender);
        primaryReceiverRoyalty = payable(msg.sender);
        lastGrinder = payable(msg.sender);

        royaltyPriceCompensationShareNumerator = 101_00; // 101%
        royaltyPricePrimaryReceiverShareNumerator = 1_00; // 1%
        royaltyPricePoolOwnerShareNumerator = 5_00; // 5%
        royaltyPriceLastGrinderShareNumerator = 50; // 0.5%
        // total share in buy royalty = 101% + 1% + 5% + 0.5% = 107.5%
        initRoyaltyPriceNumerator = 10_00; // 10%
        // primaryReceiverRoyaltyShareNumerator + receiverRoyaltyShareNumerator + lastGrinderRoyaltyShareNumerator == DENOMINATOR
        royaltyNumerator = 10_00; // 10%
        primaryReceiverRoyaltyShareNumerator = 19_00; // 19%
        receiverRoyaltyShareNumerator = 80_00; // 80%
        lastGrinderRoyaltyShareNumerator = 1_00; // 1%
        //  profit = 1 USDT
        //  profit to pool owner = 1 * 90% = 0.9 USDT
        //  royalty = 1 * 10% = 0.1 USDT
        //      royalty primary receiver = 0.1 * 19% = 0.019 USDT
        //      royalty receiver = 0.1 * 80% = 0.08 USDT
        //      royalty last grinder = 0.1 * 1% = 0.001 USDT
        isStrategiest[msg.sender] = true;
    }

    function _onlyOwner() private view {
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    function _onlyOwnerOf(uint256 poolId) private view {
        address _ownerOf = ownerOf(poolId);
        if (msg.sender != _ownerOf) {
            revert NotOwnerOfPool(poolId, _ownerOf);
        }
    }

    function _onlyStrategiest() private view {
        if (!isStrategiest[msg.sender]) revert NotStrategiest();
    }

    /// @notice sets base URI
    /// @param _baseURI string with baseURI
    function setBaseURI(string memory _baseURI) public {
        _onlyOwner();
        baseURI = _baseURI;
    }

    /////// ONLY OWNER FUNCTIONS

    /// @notice sets strategiest
    /// @dev callable only by owner
    function setStrategiest(address strategiest, bool _isStrategiest) public {
        _onlyOwner();
        isStrategiest[strategiest] = _isStrategiest;
    }

    /// @notice sets start royalty price
    /// @dev callable only by owner
    function setStartRoyaltyPrice(uint16 _initRoyaltyPriceNumerator) public {
        _onlyOwner();
        if (_initRoyaltyPriceNumerator == 0) {
            revert StartRoyaltyPriceNumeratorZero();
        }
        initRoyaltyPriceNumerator = _initRoyaltyPriceNumerator;
    }

    /// @notice sets royalty numerator amount of native token
    /// @dev callable only by owner
    function setRoyaltyNumerator(uint16 _royaltyNumerator) public {
        _onlyOwner();
        if (_royaltyNumerator > MAX_ROYALTY_NUMERATOR) {
            revert RoyaltyNumeratorExceedsMaxValue();
        }
        if (_royaltyNumerator == 0) {
            revert RoyaltyNumeratorZero();
        }
        royaltyNumerator = _royaltyNumerator;
    }

    /// @notice sets primary receiver royalty share
    /// @dev callable only by owner
    function setRoyaltyShares(
        uint16 _primaryReceiverRoyaltyShareNumerator,
        uint16 _receiverRoyaltyShareNumerator,
        uint16 _lastGrinderRoyaltyShareNumerator
    ) public {
        _onlyOwner();
        if (
            _primaryReceiverRoyaltyShareNumerator + _receiverRoyaltyShareNumerator + _lastGrinderRoyaltyShareNumerator
                != DENOMINATOR
        ) {
            revert InvalidRoyaltyShares();
        }
        primaryReceiverRoyaltyShareNumerator = _primaryReceiverRoyaltyShareNumerator;
        receiverRoyaltyShareNumerator = _receiverRoyaltyShareNumerator;
        lastGrinderRoyaltyShareNumerator = _lastGrinderRoyaltyShareNumerator;
    }

    /// @notice sets royalty price share to actors
    /// @dev callable only by owner
    function setRoyaltyPriceShares(
        uint16 _royaltyPriceCompensationShareNumerator,
        uint16 _royaltyPricePrimaryReceiverShareNumerator,
        uint16 _royaltyPricePoolOwnerShareNumerator,
        uint16 _royaltyPriceLastGrinderShareNumerator
    ) public {
        _onlyOwner();
        if (_royaltyPriceCompensationShareNumerator <= DENOMINATOR) {
            revert InvalidRoyaltyPriceShare();
        }
        royaltyPriceCompensationShareNumerator = _royaltyPriceCompensationShareNumerator;
        royaltyPricePrimaryReceiverShareNumerator = _royaltyPricePrimaryReceiverShareNumerator;
        royaltyPricePoolOwnerShareNumerator = _royaltyPricePoolOwnerShareNumerator;
        royaltyPriceLastGrinderShareNumerator = _royaltyPriceLastGrinderShareNumerator;
    }

    /// @notice sets grind token
    /// @dev sets only once
    function setGrindToken(address _grindToken) public {
        _onlyOwner();
        grindToken = IGrindToken(_grindToken);
    }

    /// @notice First step for transfering ownership
    function transferOwnership(address newOwner) public {
        _onlyOwner();
        pendingOwner = payable(newOwner);
    }

    /// @notice Second step for transfering ownership
    function acceptOwnership() public {
        if (msg.sender != pendingOwner) {
            revert NotPendingOwner();
        }
        owner = pendingOwner;
        pendingOwner = payable(address(0));
    }

    /// @notice first step to transfer primary receiver royalty
    function transferPrimaryReceiverRoyalty(address _primaryReceiverRoyalty) public {
        if (msg.sender != primaryReceiverRoyalty) {
            revert NotPrimaryReceiverRoyalty();
        }
        pendingPrimaryReceiverRoyalty = payable(_primaryReceiverRoyalty);
    }

    /// @notice second step to transfer primary royalty receiver
    function acceptPrimaryReceiver() public {
        if (msg.sender != pendingPrimaryReceiverRoyalty) {
            revert NotPendingPrimaryReceiverRoyalty();
        }
        primaryReceiverRoyalty = pendingPrimaryReceiverRoyalty;
        pendingPrimaryReceiverRoyalty = payable(address(0));
    }

    /////// ONLY STRATEGIEST FUNCTIONS

    /// @notice set factrory strategy
    /// @dev callable only by strategiest
    function setFactoryStrategy(address _factoryStrategy) public {
        _onlyStrategiest();
        uint16 strategyId = IFactoryGrindURUSPoolStrategy(_factoryStrategy).strategyId();
        factoryStrategy[strategyId] = IFactoryGrindURUSPoolStrategy(_factoryStrategy);
        emit SetFactoryStrategy(strategyId, _factoryStrategy);
    }

    /////// PUBLIC FUNCTIONS

    /// @notice mints NFT with deployment of strategy
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
    ) public returns (uint256 poolId) {
        poolId = totalPools;
        IGrindURUSPoolStrategy pool = factoryStrategy[strategyId].deploy(
            poolId, oracleQuoteTokenPerFeeToken, oracleQuoteTokenPerBaseToken, feeToken, baseToken, quoteToken
        );
        pools[poolId] = address(pool);
        poolIds[address(pool)] = poolId;
        _mint(msg.sender, poolId);
        totalPools++;
        royaltyPrice[poolId] = calcInitialRoyaltyPrice(poolId, quoteTokenAmount);

        emit Mint(poolId, oracleQuoteTokenPerFeeToken, oracleQuoteTokenPerBaseToken, feeToken, baseToken, quoteToken);
        _deposit(pool, IToken(quoteToken), quoteTokenAmount);
        emit Deposit(poolId, address(pool), quoteToken, quoteTokenAmount);
    }

    /// @notice deposit `quoteToken` to pool with `poolId`
    /// @dev callable only by owner of poolId
    /// @param poolId id of pool in array `pools`
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return deposited amount of deposited `quoteToken`
    function deposit(uint256 poolId, uint256 quoteTokenAmount) public returns (uint256 deposited) {
        _onlyOwnerOf(poolId);
        IGrindURUSPoolStrategy pool = IGrindURUSPoolStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        deposited = _deposit(pool, quoteToken, quoteTokenAmount);
        emit Deposit(poolId, address(pool), address(quoteToken), quoteTokenAmount);
    }

    /// @dev make transfer from msg.sender, approve to pool, call deposit on pool
    function _deposit(IGrindURUSPoolStrategy pool, IToken quoteToken, uint256 quoteTokenAmount)
        internal
        returns (uint256 deposited)
    {
        quoteToken.safeTransferFrom(msg.sender, address(this), quoteTokenAmount);
        quoteToken.forceApprove(address(pool), quoteTokenAmount);
        deposited = pool.deposit(quoteTokenAmount);
    }

    /// @notice withdraw `quoteToken` from poolId to `msg.sender`
    /// @dev callcable only by owner of poolId
    function withdraw(uint256 poolId, uint256 quoteTokenAmount) public returns (uint256 withdrawn) {
        withdrawn = withdrawTo(poolId, msg.sender, quoteTokenAmount);
    }

    /// @notice withdraw `quoteToken` from poolId to `to`
    /// @dev callcable only by owner of poolId.
    /// @dev withdrawable when distrubution is 100% quoteToken + 0% baseToken
    /// @param poolId pool id of pool in array `pools`
    /// @param to address of receiver of withdrawed funds
    /// @param quoteTokenAmount amount of `quoteToken`
    /// @return withdrawn amount of withdrawn quoteToken
    function withdrawTo(uint256 poolId, address to, uint256 quoteTokenAmount) public returns (uint256 withdrawn) {
        _onlyOwnerOf(poolId);
        IGrindURUSPoolStrategy pool = IGrindURUSPoolStrategy(pools[poolId]);
        IToken quoteToken = pool.getQuoteToken();
        withdrawn = pool.withdraw(to, quoteTokenAmount);
        emit Withdraw(poolId, to, address(quoteToken), quoteTokenAmount);
    }

    /// @notice exit from strategy and transfer ownership to royalty receiver
    /// @dev callable only by owner of poolId
    /// @param poolId pool id of pool in array `pools`
    function exit(uint256 poolId) public returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        _onlyOwnerOf(poolId);
        IGrindURUSPoolStrategy pool = IGrindURUSPoolStrategy(pools[poolId]);
        (quoteTokenAmount, baseTokenAmount) = pool.exit();
        address poolOwner = ownerOf(poolId);
        address newPoolOwner = getRoyaltyReceiver(poolId);
        transferFrom(poolOwner, newPoolOwner, poolId);
        emit Exit(poolId, quoteTokenAmount, baseTokenAmount);
    }

    /// @notice rebalance the pools with poolIds `poolIdLeft` and `poolIdRight`
    /// @dev only owner of pools can rebalance with equal strategy id
    /// @param poolIdLeft pool id of pool to rebalance
    /// @param poolIdRight pool id of pool to rebalance
    function rebalance(uint256 poolIdLeft, uint256 poolIdRight) public {
        _onlyOwnerOf(poolIdLeft);
        if (ownerOf(poolIdLeft) != ownerOf(poolIdRight)) {
            revert NotAllowedToRebalance();
        }
        IGrindURUSPoolStrategy poolLeft = IGrindURUSPoolStrategy(pools[poolIdLeft]);
        IGrindURUSPoolStrategy poolRight = IGrindURUSPoolStrategy(pools[poolIdRight]);
        if (poolLeft.strategyId() != poolRight.strategyId()) {
            revert DifferentStrategyId();
        }
        IToken poolLeftBaseToken = poolLeft.getBaseToken();
        IToken poolRightBaseToken = poolRight.getBaseToken();
        IToken poolLeftQuoteToken = poolLeft.getQuoteToken();
        IToken poolRightQuoteToken = poolRight.getQuoteToken();
        if (address(poolLeftBaseToken) != address(poolRightBaseToken)) {
            revert DifferentBaseTokens();
        }
        if (address(poolLeftQuoteToken) != address(poolRightQuoteToken)) {
            revert DifferentQuoteTokens();
        }

        (uint256 baseTokenAmountLeft, uint256 priceLeft) = poolLeft.beforeRebalance();
        (uint256 baseTokenAmountRight, uint256 priceRight) = poolRight.beforeRebalance();
        // second step: rebalance
        uint256 totalBaseTokenAmount = baseTokenAmountLeft + baseTokenAmountRight;
        uint256 rebalancedPrice =
            (baseTokenAmountLeft * priceLeft + baseTokenAmountRight * priceRight) / totalBaseTokenAmount;
        uint256 newBaseTokemAmountLeft = totalBaseTokenAmount / 2;
        uint256 newBaseTokemAmountRight = totalBaseTokenAmount - newBaseTokemAmountLeft;

        poolLeftBaseToken.forceApprove(address(poolLeft), newBaseTokemAmountLeft);
        poolRightBaseToken.forceApprove(address(poolRight), newBaseTokemAmountRight);
        poolLeft.afterRebalance(newBaseTokemAmountLeft, rebalancedPrice);
        poolRight.afterRebalance(newBaseTokemAmountRight, rebalancedPrice);
    }

    /// @notice grind the pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    function grind(uint256 poolId) public {
        IGrindURUSPoolStrategy strategy = IGrindURUSPoolStrategy(pools[poolId]);
        (
            IGrindURUSPoolStrategy.Position memory long,
            IGrindURUSPoolStrategy.Position memory hedge,
            IGrindURUSPoolStrategy.Config memory config
        ) = strategy.getLongHedgeAndConfig();
        uint8 longNumber = long.number;
        uint8 hedgeNumber = hedge.number;
        uint8 longNumberMax = config.longNumberMax;
        if (longNumber < longNumberMax) {
            if (longNumber == 0) {
                try strategy.long_buy() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit LongBuy(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
            } else {
                try strategy.long_sell() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit LongSell(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
                try strategy.long_buy() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit LongBuy(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
            }
        } else {
            if (hedgeNumber == 0) {
                try strategy.hedge_sell() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit HedgeSell(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
            } else {
                try strategy.hedge_rebuy() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit HedgeRebuy(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
                try strategy.hedge_sell() returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
                    rewardActors(poolId);
                    emit HedgeSell(poolId, quoteTokenAmount, baseTokenAmount);
                } catch {}
            }
        }
        lastGrinder = payable(msg.sender);
        emit Grind(poolId, msg.sender);
    }

    /// @notice reward actors for participation in protocol
    /// @param poolId pool id of pool in array `pools`
    function rewardActors(uint256 poolId) internal {
        address grinder = msg.sender;
        grindToken.rewardGrinder(grinder);
        grindToken.rewardPoolOwner(ownerOf(poolId));
        grindToken.rewardRoyaltyReceiver(getRoyaltyReceiver(poolId));
        grindToken.rewardOwner(owner);
    }

    /// @notice buy royalty for pool with `poolId`
    /// @param poolId pool id of pool in array `pools`
    /// @return royaltyPricePaid paid for royalty
    /// @return refund excess of msg.value
    function buyRoyalty(uint256 poolId)
        public
        payable
        nonReentrant
        returns (uint256 royaltyPricePaid, uint256 refund)
    {
        (
            uint256 compensationShare, // oldRoyaltyPrice + compensation
            uint256 poolOwnerShare,
            uint256 primaryReceiverShare,
            uint256 lastGrinderShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        ) = royaltyPriceShares(poolId);
        oldRoyaltyPrice;
        if (msg.value < newRoyaltyPrice) {
            revert InsufficientRoyaltyPrice();
        }
        address payable _oldRoyaltyReceiver = payable(royaltyReceiver[poolId]);
        address payable _poolOwner = payable(ownerOf(poolId));
        address payable _primaryReceiverRoyalty = primaryReceiverRoyalty;
        address payable _newRoyaltyReceiver = payable(msg.sender);

        royaltyReceiver[poolId] = _newRoyaltyReceiver;
        royaltyPrice[poolId] = newRoyaltyPrice; // newRoyaltyPrice always increase!
        bool success;
        if (compensationShare > 0) {
            (success,) = _oldRoyaltyReceiver.call{value: compensationShare}("");
            if (!success) {
                (success,) = owner.call{value: compensationShare}("");
                if (!success) {
                    revert FailCompensationShare();
                }
            }
            royaltyPricePaid += compensationShare;
        }
        if (poolOwnerShare > 0) {
            (success,) = _poolOwner.call{value: poolOwnerShare}("");
            if (!success) {
                (success,) = owner.call{value: poolOwnerShare}("");
                if (!success) {
                    revert FailPoolOwnerShare();
                }
            }
            royaltyPricePaid += poolOwnerShare;
        }
        if (primaryReceiverShare > 0) {
            (success,) = _primaryReceiverRoyalty.call{value: primaryReceiverShare}("");
            if (!success) {
                (success,) = owner.call{value: primaryReceiverShare}("");
                if (!success) {
                    revert FailPrimaryReceiverShare();
                }
            }
            royaltyPricePaid += primaryReceiverShare;
        }
        if (lastGrinderShare > 0) {
            (success,) = lastGrinder.call{value: lastGrinderShare}("");
            if (!success) {
                (success,) = owner.call{value: lastGrinderShare}("");
                if (!success) {
                    revert FailLastGrinderShare();
                }
            }
            royaltyPricePaid += lastGrinderShare;
        }
        refund = msg.value - royaltyPricePaid;
        if (refund > 0) {
            (success,) = _newRoyaltyReceiver.call{value: refund}("");
            if (!success) {
                (success,) = owner.call{value: refund}("");
                if (!success) {
                    revert FailRefund();
                }
            }
        }
    }

    /// @notice buy grindurus ownership for `grindurusOwnershipPrice()` to owner
    /// @return ownershipPricePaid paid ownership price
    /// @return refund refund to buyer of royalty
    function buyOwnership() public payable nonReentrant returns (uint256 ownershipPricePaid, uint256 refund) {
        address payable _owner = payable(owner);
        address payable _sender = payable(msg.sender);
        uint256 _grindurusOwnershipPrice = grindurusOwnershipPrice();

        if (msg.value < _grindurusOwnershipPrice) {
            revert InsufficientBuyOwnership();
        }

        owner = _sender;
        bool success;
        (success,) = _owner.call{value: _grindurusOwnershipPrice}("");
        if (!success) {
            revert FailBuyOwnership();
        }

        ownershipPricePaid = _grindurusOwnershipPrice;
        refund = msg.value - _grindurusOwnershipPrice;
        if (refund > 0) {
            (success,) = _sender.call{value: refund}("");
            if (!success) {
                emit ReceiveETH(refund);
            }
        }
    }

    /// @notice The protocol ownership of grindurus price 0.1 million ETH
    function grindurusOwnershipPrice() public pure returns (uint256) {
        return 100_000 ether;
    }

    /// @notice implementation of royalty standart ERC2981
    /// @param tokenId pool id of pool in array `pools`
    /// @param salePrice amount of asset
    /// @return receiver address of receiver
    /// @return royaltyAmount amount of royalty
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 poolId = tokenId;
        receiver = getRoyaltyReceiver(poolId);
        royaltyAmount = salePrice * royaltyNumerator / DENOMINATOR;
    }

    /// @notice calculates royalty shares
    /// @param poolId pool id of pool in array `pools`
    /// @param profit amount of token to be distributed
    /// @dev returns array of receivers and amounts
    function royaltyShares(uint256 poolId, uint256 profit)
        public
        view
        override
        returns (uint8 length, address[] memory receivers, uint256[] memory amounts)
    {
        length = 3;
        receivers = new address[](length);
        amounts = new uint256[](length);
        receivers[0] = primaryReceiverRoyalty;
        receivers[1] = getRoyaltyReceiver(poolId);
        receivers[2] = lastGrinder;
        uint256 denominator = DENOMINATOR;
        amounts[0] = profit * primaryReceiverRoyaltyShareNumerator / denominator;
        amounts[1] = profit * receiverRoyaltyShareNumerator / denominator;
        amounts[2] = profit * lastGrinderRoyaltyShareNumerator / denominator;
    }

    /// @notice calc royalty prices
    /// @param poolId pool id of pool in array `pools`
    /// @return compensationShare feeToken amount to be received to old owner as compensation
    /// @return poolOwnerShare feeToken amount to be received by pool owner
    /// @return primaryReceiverShare feeToken amount to be received by primary royalty receiver
    /// @return lastGrinderShare feeToken amount to be received to last grinder
    /// @return oldRoyaltyPrice feeToken amount of old royalty price
    /// @return newRoyaltyPrice feeToken amount of new royalty price
    function royaltyPriceShares(uint256 poolId)
        public
        view
        returns (
            uint256 compensationShare,
            uint256 poolOwnerShare,
            uint256 primaryReceiverShare,
            uint256 lastGrinderShare,
            uint256 oldRoyaltyPrice,
            uint256 newRoyaltyPrice
        )
    {
        uint256 _royaltyPrice = royaltyPrice[poolId];
        uint256 _denominator = DENOMINATOR;
        compensationShare = _royaltyPrice * royaltyPriceCompensationShareNumerator / _denominator;
        poolOwnerShare = _royaltyPrice * royaltyPricePoolOwnerShareNumerator / _denominator;
        primaryReceiverShare = _royaltyPrice * royaltyPricePrimaryReceiverShareNumerator / _denominator;
        lastGrinderShare = _royaltyPrice * royaltyPriceLastGrinderShareNumerator / _denominator;
        oldRoyaltyPrice = _royaltyPrice;
        newRoyaltyPrice = compensationShare + poolOwnerShare + primaryReceiverShare + lastGrinderShare;
    }

    /// @notice calc initial royalty price
    /// @param poolId pool id of pool in array `pools`
    /// @param quoteTokenAmount amount of `quoteToken`
    function calcInitialRoyaltyPrice(uint256 poolId, uint256 quoteTokenAmount)
        public
        view
        returns (uint256 initRoyaltyPrice)
    {
        uint256 feeTokenAmount = IGrindURUSPoolStrategy(pools[poolId]).calcFeeTokenByQuoteToken(quoteTokenAmount);
        initRoyaltyPrice = feeTokenAmount * initRoyaltyPriceNumerator / DENOMINATOR;
    }

    /// @notice returns tokenURI of `tokenId`
    /// @param tokenId pool id of pool in array `pools`
    /// @return uri unified reference indentificator for `tokenId`
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        _requireOwned(tokenId);
        uint256 poolId = tokenId;
        // https://api.grindurus.io/{poolId}/info.json
        string memory path = string.concat(baseURI, poolId.toString());
        string memory file = "/info.json";
        uri = string.concat(path, file);
    }

    /// @inheritdoc ERC721
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, IERC165) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId);
    }

    /// @notice return royalty receiver
    /// @param poolId pool id of pool in array `pools`
    /// @return receiver address of royalty receiver
    function getRoyaltyReceiver(uint256 poolId) public view returns (address receiver) {
        receiver = royaltyReceiver[poolId];
        if (receiver == address(0)) {
            receiver = primaryReceiverRoyalty;
        }
    }

    /// @notice gets pool ids owned by `poolOwner`
    /// @param poolOwner address of pool owner
    /// @return totalPoolIds total amount of pool ids owned by `poolOwner`
    /// @return poolIdsOwnedByPoolOwner array of owner pool ids
    function getPoolIdsOf(address poolOwner)
        public
        view
        returns (uint256 totalPoolIds, uint256[] memory poolIdsOwnedByPoolOwner)
    {
        totalPoolIds = balanceOf(poolOwner);
        if (totalPoolIds == 0) {
            return (0, new uint256[](1));
        }
        uint256 i = 0;
        poolIdsOwnedByPoolOwner = new uint256[](totalPoolIds);
        for (; i < totalPoolIds;) {
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
    function getPoolNFTInfos(uint256 fromPoolId, uint256 toPoolId)
        public
        view
        returns (PoolNFTInfo[] memory poolsInfo)
    {
        if (fromPoolId > toPoolId) {
            revert InvalidPoolNFTInfos();
        }
        poolsInfo = new PoolNFTInfo[](toPoolId - fromPoolId + 1);
        uint256 poolId = fromPoolId;
        uint256 poolInfoId = 0;
        for (; poolId <= toPoolId;) {
            IGrindURUSPoolStrategy pool = IGrindURUSPoolStrategy(pools[poolId]);
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

    /// @notice returns long position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getLong(uint256 poolId)
        public
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
        (number, numberMax, priceMin, liquidity, qty, price, feeQty, feePrice) =
            IGrindURUSPoolStrategy(pools[poolId]).getLong();
    }

    /// @notice returns hedge position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getHedge(uint256 poolId)
        public
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
        (number, numberMax, priceMin, liquidity, qty, price, feeQty, feePrice) =
            IGrindURUSPoolStrategy(pools[poolId]).getHedge();
    }

    /// @notice returns long position of poolId
    /// @param poolId pool id of pool in array `pools`
    function getConfig(uint256 poolId)
        public
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
        IGrindURUSPoolStrategy pool = IGrindURUSPoolStrategy(pools[poolId]);
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

    /// @notice return the balance of token on this contract
    /// @param token address of token
    /// @return balance of token on this smart contract
    function balance(address token) public view returns (uint256) {
        return IToken(token).balanceOf(address(this));
    }

    /// @notice sweep token from this smart contract to `to`
    /// @param token address of ERC20 token
    /// @param to address of receiver fee amount
    function sweep(address token, address to) public payable {
        _onlyOwner();
        uint256 _balance;
        if (token == address(0)) {
            _balance = address(this).balance;
            if (_balance == 0) {
                revert ZeroETH();
            }
            (bool success,) = payable(to).call{value: _balance}("");
            if (!success) {
                revert FailETHTransfer();
            }
        } else {
            IToken _token = IToken(token);
            _balance = _token.balanceOf(address(this));
            if (_balance == 0) {
                revert FailTokenTransfer(token);
            }
            _token.safeTransfer(to, _balance);
        }
    }

    receive() external payable {
        if (msg.value > 0) {
            (bool success,) = owner.call{value: msg.value}("");
            if (!success) {
                emit ReceiveETH(msg.value);
            }
        }
    }
}
