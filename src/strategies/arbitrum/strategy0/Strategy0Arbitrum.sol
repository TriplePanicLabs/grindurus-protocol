// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IURUS, URUS, IERC5313} from "src/URUS.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDexAdapter} from "src/interfaces/IDexAdapter.sol";
import {NoLendingAdapter} from "src/adapters/lendings/NoLendingAdapter.sol";
import {UniswapV3AdapterArbitrum} from "src/adapters/dexes/UniswapV3AdapterArbitrum.sol";

/// @title Strategy0
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice strategy pool, that implements pure URUS algorithm
/// @dev Pure URUS algorithm on UniswapV3. Stores tokens on Strategy0 and hadles tokens swaps
contract Strategy0Arbitrum is IStrategy, URUS, NoLendingAdapter, UniswapV3AdapterArbitrum {
    using SafeERC20 for IToken;

    /// @dev address of NFT collection of pools
    /// @dev if address dont implement interface `IPoolsNFT`, that owner is this address
    IPoolsNFT public poolsNFT;

    /// @dev index of position in `poolsNFT`
    uint256 public poolId;

    /// @dev true - reinvest, false - not reinvest
    bool public reinvest;

    constructor () {}

    /// @dev checks that msg.sender is owner
    function _onlyOwner() internal view virtual {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @dev checks that msg.sender is gateway
    function _onlyGateway() internal view virtual {
        if (msg.sender != address(poolsNFT)) {
            revert NotGateway();
        }
    }

    /// @dev checks that msg.sender is agent
    function _onlyAgent() internal view virtual {
        try poolsNFT.isAgentOf(owner(), msg.sender) returns (bool isAgent) {
            if (!isAgent) {
                revert NotAgent();
            }
        } catch {
            if (owner() != address(poolsNFT)) {
                revert NotAgent();
            }
        }
    }

    /// @dev constuctor of PoolStrategy0
    /// @param _poolsNFT address of poolsNFT
    /// @param _poolId id of poolNFT
    /// @param _oracleQuoteTokenPerFeeToken address of oracle of quoteToken per fee token
    /// @param _oracleQuoteTokenPerBaseToken address of oracle of quoteToken per base token
    /// @param _feeToken address of fee token
    /// @param _baseToken address of base token
    /// @param _quoteToken address of quote token
    /// @param _config config for URUS algorithm
    /// @param _dexArgs encoded data for dex adapter
    function init(
        address _poolsNFT,
        uint256 _poolId,
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _baseToken,
        address _quoteToken,
        Config memory _config,
        bytes memory _dexArgs
    ) public {
        require(address(poolsNFT) == address(0));
        initURUS(
            _oracleQuoteTokenPerFeeToken,
            _oracleQuoteTokenPerBaseToken,
            _feeToken,
            _baseToken,
            _quoteToken,
            _config
        );
        initDex(_dexArgs);

        poolsNFT = IPoolsNFT(_poolsNFT);
        poolId = _poolId;
        startTimestamp = block.timestamp;
        reinvest = true;
    }

    function setConfig(Config memory conf) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setConfig(conf);
    }

    function setLongNumberMax(uint8 longNumberMax) public override(URUS, IURUS) {
        _onlyAgent(); 
        URUS.setLongNumberMax(longNumberMax);
    }

    function setHedgeNumberMax(uint8 hedgeNumberMax) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setHedgeNumberMax(hedgeNumberMax);
    }

    function setExtraCoef(uint256 extraCoef) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setExtraCoef(extraCoef);
    }

    function setPriceVolatilityPercent(uint256 priceVolatilityPercent) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setPriceVolatilityPercent(priceVolatilityPercent);
    }

    function setOpReturnPercent(uint8 op, uint256 returnPercent) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setOpReturnPercent(op, returnPercent);
    }

    function setOpFeeCoef(uint8 op, uint256 _feeCoef) public override(URUS, IURUS) {
        _onlyAgent();
        URUS.setOpFeeCoef(op, _feeCoef);
    }

    function deposit(uint256 quoteTokenAmount) public override(URUS, IURUS) returns (uint256) {
        _onlyGateway(); 
        return URUS.deposit(quoteTokenAmount);
    }

    function deposit2(
        uint256 baseTokenAmount,
        uint256 baseTokenPrice
    ) public override(URUS, IURUS) returns (uint256) {
        _onlyGateway();
        return URUS.deposit2(baseTokenAmount, baseTokenPrice);
    }

    function deposit3(uint256 quoteTokenAmount) public override(URUS, IURUS) returns (uint256) {
        _onlyGateway();
        return URUS.deposit3(quoteTokenAmount);
    }

    function withdraw(
        address to,
        uint256 quoteTokenAmount
    ) public override(URUS, IURUS) returns (uint256) {
        _onlyGateway();
        return URUS.withdraw(to, quoteTokenAmount);
    }

    function withdraw2(
        address to,
        uint256 baseTokenAmount
    ) public override(URUS, IURUS) returns (uint256) {
        _onlyGateway();
        return URUS.withdraw2(to, baseTokenAmount);
    }

    /// @notice exit funds from strategy
    function exit() public override(URUS, IURUS) returns (uint256 quoteTokenAmount, uint256 baseTokenAmount) {
        _onlyGateway();
        bool storedReinvest = reinvest;
        reinvest = false;
        (quoteTokenAmount, baseTokenAmount) = URUS.exit();
        reinvest = storedReinvest;
    }

    function beforeRebalance() public override(URUS, IURUS) returns (uint256 baseTokenAmount, uint256 price) {
        _onlyGateway();
        return URUS.beforeRebalance();
    }

    function afterRebalance(uint256 baseTokenAmount, uint256 newPrice) public override(URUS, IURUS) {
        _onlyGateway();
        return URUS.afterRebalance(baseTokenAmount, newPrice);
    }

    function _put(IToken token, uint256 amount) internal override(NoLendingAdapter, URUS) returns (uint256){
        return NoLendingAdapter._put(token, amount);
    }

    function _take(IToken token, uint256 amount) internal override(NoLendingAdapter, URUS) returns (uint256) {
        return NoLendingAdapter._take(token, amount);
    }

    function setSwapRouter(address _swapRouter) public override(UniswapV3AdapterArbitrum) {
        _onlyAgent();
        UniswapV3AdapterArbitrum.setSwapRouter(_swapRouter);
    }

    function setUniswapV3PoolFee(uint24 _uniswapV3PoolFee) public override(UniswapV3AdapterArbitrum) {
        _onlyAgent();
        UniswapV3AdapterArbitrum.setUniswapV3PoolFee(_uniswapV3PoolFee);
    }

    function _swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) internal override(UniswapV3AdapterArbitrum, URUS) returns (uint256) {
        return UniswapV3AdapterArbitrum._swap(tokenIn, tokenOut, amountIn);
    }

    function getPendingYield(IToken token) public view override (URUS, NoLendingAdapter) returns (uint256) {
        return NoLendingAdapter.getPendingYield(token);
    }

    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal override (URUS, NoLendingAdapter) {
        URUS._distributeYieldProfit(token, profit);
    } 

    function _distributeTradeProfit(
        IToken token,
        uint256 profit
    ) internal override (URUS) {
        URUS._distributeTradeProfit(token, profit);
    }

    /// @notice distribute profit
    /// @param token address of token
    /// @param profit amount of token
    function _distributeProfit(IToken token, uint256 profit) internal override (URUS) {
        (
            address[] memory receivers,
            uint256[] memory amounts
        ) = poolsNFT.calcRoyaltyShares(poolId, profit);
        uint256 len = receivers.length;
        require(len == amounts.length);
        if (reinvest) {
            uint256 quoteTokenAmount;
            if (token == quoteToken) {
                quoteTokenAmount = amounts[0];
            } else {
                quoteTokenAmount = _swap(getBaseToken(), getQuoteToken(), amounts[0]);
            }
            _invest(quoteTokenAmount);
            _put(quoteToken, quoteTokenAmount);
        } else {
            token.safeTransfer(receivers[0], amounts[0]);
        }
        uint256 i = 1;
        for (;i < len;) {
            if (amounts[i] > 0) {
                token.safeTransfer(receivers[i], amounts[i]);
            }
            unchecked { ++i; }
        }
    }

    /// @notice switch reinvest flag
    function switchReinvest() external override {
        _onlyOwner();
        reinvest = !reinvest;
    }

    /// @notice execute any transaction
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    /// @return success true if transaction was successful
    /// @return result data returned from target contract
    function execute(address target, uint256 value, bytes calldata data) public payable override(URUS, IURUS) returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }

    /// @notice calculates return of investment of strategy pool.
    /// @dev returns the numerator and denominator of ROI. ROI = ROINumerator / ROIDenominator
    function ROI()
        public
        view
        returns (
            uint256 ROINumerator,
            uint256 ROIDenominator,
            uint256 ROIPeriod
        )
    {
        uint256 baseTokenPrice = getPriceQuoteTokenPerBaseToken();
        uint256 investment = quoteToken.balanceOf(address(this)) +
            calcQuoteTokenByBaseToken(
                baseToken.balanceOf(address(this)),
                baseTokenPrice
            );
        uint256 profitsSum = 0 + // trade profits + yield profits + pending yield profits
            profits.quoteTokenTradeProfit +
            calcQuoteTokenByBaseToken(
                profits.baseTokenTradeProfit,
                baseTokenPrice
            ) +
            profits.quoteTokenYieldProfit +
            calcQuoteTokenByBaseToken(
                profits.baseTokenYieldProfit,
                baseTokenPrice
            ) +
            getPendingYield(quoteToken) +
            getPendingYield(baseToken);
        ROINumerator = profitsSum;
        ROIDenominator = investment;
        ROIPeriod = block.timestamp - startTimestamp;
    }

    /// @notice return pool total active capital based on positions
    /// @dev [activeCapital] = quoteToken
    function getActiveCapital() external view returns (uint256) {
        return 
            quoteToken.balanceOf(address(this)) + 
            calcQuoteTokenByBaseToken(long.qty, long.price) +
            calcQuoteTokenByBaseToken(hedge.qty, hedge.price);
    }

    /// @notice returns strategy id
    function strategyId() external pure override returns (uint16) {
        return 0;
    }

    /// @notice returns the owner of strategy
    function owner() public view override(URUS, IERC5313) returns (address) {
        try poolsNFT.ownerOf(poolId) returns (address _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice returns quote token
    function getQuoteToken() public view override(UniswapV3AdapterArbitrum, IStrategy) returns (IToken) {
        return quoteToken;
    }

    /// @notice returns base token
    function getBaseToken() public view override(UniswapV3AdapterArbitrum, IStrategy) returns (IToken) {
        return baseToken;
    }

    /// @notice returns quoteToken amount
    function getQuoteTokenAmount() public view override returns (uint256) {
        return quoteToken.balanceOf(address(this));
    }

    /// @notice returns base token amount
    function getBaseTokenAmount() public view override returns (uint256) {
        return baseToken.balanceOf(address(this));
    }

}