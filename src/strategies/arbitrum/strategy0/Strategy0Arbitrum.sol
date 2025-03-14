// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {URUS, IERC5313} from "src/URUS.sol";
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

    /// @dev timestamp of deployment
    uint256 public startTimestamp;

    constructor () {}

    function init(
        address _poolsNFT,
        uint256 _poolId,
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _quoteToken,
        address _baseToken,
        Config memory _config,
        bytes memory _dexArgs
    ) public {
        if (address(poolsNFT) != address(0)) {
            revert StrategyInitialized(strategyId());
        }
        initURUS(
            _oracleQuoteTokenPerFeeToken,
            _oracleQuoteTokenPerBaseToken,
            _feeToken,
            _quoteToken,
            _baseToken,
            _config
        );
        initDex(_dexArgs);

        poolsNFT = IPoolsNFT(_poolsNFT);
        poolId = _poolId;
        startTimestamp = block.timestamp;
    }

    /// @dev checks that msg.sender is owner
    function _onlyOwner() internal view override(URUS) {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @dev checks that msg.sender is gateway
    function _onlyGateway() internal view override(URUS) {
        if (msg.sender != address(poolsNFT)) {
            revert NotPoolsNFT();
        }
    }

    /// @dev checks that msg.sender is agent
    function _onlyAgent() internal view override(URUS, NoLendingAdapter, UniswapV3AdapterArbitrum) {
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

    function _put(IToken token, uint256 amount) internal override(NoLendingAdapter, URUS) returns (uint256){
        return NoLendingAdapter._put(token, amount);
    }

    function _take(IToken token, uint256 amount) internal override(NoLendingAdapter, URUS) returns (uint256) {
        return NoLendingAdapter._take(token, amount);
    }

    function _swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) internal override(UniswapV3AdapterArbitrum, URUS) returns (uint256) {
        return UniswapV3AdapterArbitrum._swap(tokenIn, tokenOut, amountIn);
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

    function _distributeProfit(IToken token, uint256 profit) internal override (URUS) {
        (
            address[] memory receivers,
            uint256[] memory amounts
        ) = poolsNFT.calcRoyaltyShares(poolId, profit);
        uint256 len = receivers.length;
        if (len != amounts.length) {
            revert InvalidLength();
        }
        uint256 i;
        for (;i < len;) {
            if (amounts[i] > 0) {
                token.safeTransfer(receivers[i], amounts[i]);
            }
            unchecked { ++i; }
        }
    }

    /// @notice execute any transaction
    function execute(address target, uint256 value, bytes calldata data) public returns (bytes memory result) {
        _onlyOwner();
        (, result) = target.call{value: value}(data);
    }

    /// @notice return total profits of strategy pool
    function getTotalProfits()
        public
        view
        override
        returns (
            uint256 quoteTokenYieldProfit,
            uint256 baseTokenYieldProfit,
            uint256 quoteTokenTradeProfit,
            uint256 baseTokenTradeProfit
        )
    {
        quoteTokenYieldProfit = totalProfits.quoteTokenYieldProfit + getPendingYield(quoteToken);
        baseTokenYieldProfit = totalProfits.baseTokenYieldProfit + getPendingYield(baseToken);
        quoteTokenTradeProfit = totalProfits.quoteTokenTradeProfit;
        baseTokenTradeProfit = totalProfits.baseTokenTradeProfit;
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
        uint256 profits = 0 + // trade profits + yield profits + pending yield profits
            totalProfits.quoteTokenTradeProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenTradeProfit,
                baseTokenPrice
            ) +
            totalProfits.quoteTokenYieldProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenYieldProfit,
                baseTokenPrice
            ) +
            getPendingYield(quoteToken) +
            getPendingYield(baseToken);
        ROINumerator = profits;
        ROIDenominator = investment;
        ROIPeriod = block.timestamp - startTimestamp;
    }

    /// @notice calculates annual percentage rate (APR) of strategy pool
    /// @dev returns the numerator and denominator of APR. APR = APRNumerator / APRDenominator
    function APR()
        public
        view
        returns (uint256 APRNumerator, uint256 APRDenominator)
    {
        (
            uint256 ROINumerator,
            uint256 ROIDenominator,
            uint256 ROIPeriod
        ) = ROI();
        // convert ROI per 1 day
        uint256 oneDayInSeconds = 86400;
        APRNumerator = ROINumerator * ROIPeriod * 365;
        APRDenominator = ROIDenominator * oneDayInSeconds;
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
    function strategyId() public pure override returns (uint16) {
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