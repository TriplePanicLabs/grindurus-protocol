// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {AggregatorV3Interface} from "src/interfaces/chainlink/AggregatorV3Interface.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {UniswapV3AdapterArbitrum} from "src/adapters/dexes/UniswapV3AdapterArbitrum.sol";
import {AAVEV3AdapterArbitrum} from "src/adapters/lendings/AAVEV3AdapterArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {URUSCore, IERC5313} from "src/URUSCore.sol";

/// @title GrindURUS Pool Strategy 1
/// @author Triple Panic Labs, CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice strategy pool, that put and take baseToken and quouteToken on AAVEV3 and swaps tokens on UniswapV3
/// @dev stores the tokens LP and handles tokens swaps
contract Strategy1Arbitrum is IStrategy, URUSCore, AAVEV3AdapterArbitrum, UniswapV3AdapterArbitrum { 
    using SafeERC20 for IToken;

    /// @dev address of NFT collection of pools
    /// @dev if address dont implement interface `IPoolsNFT`, that owner is this address
    IPoolsNFT public poolsNFT;

    /// @dev index of position in `poolsNFT`
    uint256 public poolId;

    /// @dev timestamp of deployment
    uint256 public deploymentTimestamp;

    constructor () {}

    /// @dev checks that msg.sender is owner
    function _onlyOwner() internal view override(UniswapV3AdapterArbitrum, AAVEV3AdapterArbitrum, URUSCore) {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @dev checks that msg.sender is poolsNFT
    function _onlyTrustedEntity() internal view override(URUSCore) {
        if (msg.sender != address(poolsNFT)) {
            revert NotPoolsNFT();
        }
    }

    /// @dev constuctor of PoolStrategy1
    /// @param _poolsNFT address of poolsNFT
    /// @param _poolId id of poolNFT
    /// @param _oracleQuoteTokenPerFeeToken address of oracle of quoteToken per fee token
    /// @param _oracleQuoteTokenPerBaseToken address of oracle of quoteToken per base token
    /// @param _feeToken address of fee token
    /// @param _quoteToken address of quote token
    /// @param _baseToken address of base token
    /// @param _lendingArgs encoded data for lending adapter
    /// @param _dexArgs encoded data for dex adapter
    /// @param _config config for URUS algorithm
    function init(
        address _poolsNFT,
        uint256 _poolId,
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _quoteToken,
        address _baseToken,
        bytes calldata _lendingArgs,
        bytes calldata _dexArgs,
        Config memory _config
    ) public {
        if (address(poolsNFT) != address(0)) {
            revert StrategyInitialized(strategyId());
        }
        initCore(
            _oracleQuoteTokenPerFeeToken,
            _oracleQuoteTokenPerBaseToken,
            _feeToken,
            _quoteToken,
            _baseToken,
            _config
        );
        initLending(
            _lendingArgs
        );
        initDex(
            _dexArgs
        );

        poolsNFT = IPoolsNFT(_poolsNFT);
        poolId = _poolId;
        deploymentTimestamp = block.timestamp;
    }

    /// @notice puts token to yield protocol
    /// @param token address of token
    /// @param amount amount of token to put
    function _put(IToken token, uint256 amount) internal override(AAVEV3AdapterArbitrum, URUSCore) returns (uint256 putAmount){
        putAmount = AAVEV3AdapterArbitrum._put(token, amount);
    }

    /// @notice takes token from yield protocol
    /// @param token address of token
    /// @param amount amount of token to take
    function _take(IToken token, uint256 amount) internal override(AAVEV3AdapterArbitrum, URUSCore) returns (uint256 takeAmount) {
        takeAmount = AAVEV3AdapterArbitrum._take(token, amount);
    }

    /// @notice swaps from `tokenIn` to `tokenOut` on DEX
    /// @param tokenIn address of `tokenIn`
    /// @param tokenOut address of `tokenOut`
    /// @param amountIn amount of `tokenIn`
    function _swap(IToken tokenIn, IToken tokenOut, uint256 amountIn) internal override(UniswapV3AdapterArbitrum, URUSCore) returns (uint256 amountOut) {
        amountOut = UniswapV3AdapterArbitrum._swap(tokenIn, tokenOut, amountIn);
    }

    /// @notice distribute yield profit
    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal override (URUSCore, AAVEV3AdapterArbitrum) {
        URUSCore._distributeYieldProfit(token, profit);
    } 

    /// @notice distribute trade profit
    function _distributeTradeProfit(
        IToken token,
        uint256 profit
    ) internal override (URUSCore) {
        URUSCore._distributeTradeProfit(token, profit);
    }

    /// @notice distribute profit
    function _distributeProfit(IToken token, uint256 profit) internal override (URUSCore) {
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
        uint256 investment = investedAmount[quoteToken] +
            calcQuoteTokenByBaseToken(
                investedAmount[baseToken],
                baseTokenPrice
            );
        uint256 profits = 0 + // trade profits + yield profits + pending yield profits
            totalProfits.quoteTokenTradeProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenTradeProfit,
                baseTokenPrice
            ) + // yield profits
            totalProfits.quoteTokenYieldProfit +
            calcQuoteTokenByBaseToken(
                totalProfits.baseTokenYieldProfit,
                baseTokenPrice
            ) + // pending yield profits
            getPendingYield(quoteToken) +
            calcQuoteTokenByBaseToken(
                getPendingYield(baseToken), 
                baseTokenPrice
            );
        ROINumerator = profits;
        ROIDenominator = investment;
        ROIPeriod = block.timestamp - deploymentTimestamp;
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
        uint256 secondsInYear = 365 * 24 * 60 * 60;
        APRNumerator = ROINumerator * secondsInYear;
        APRDenominator = ROIDenominator *  ROIPeriod;
    }
    
    /// @notice return pool total active capital based on positions
    /// @dev [activeCapital] = quoteToken
    function getActiveCapital() external view returns (uint256) {
        return 
            investedAmount[quoteToken] + 
            calcQuoteTokenByBaseToken(long.qty, long.price) +
            calcQuoteTokenByBaseToken(hedge.qty, hedge.price);
    }

    /// @notice returns strategy id
    function strategyId() public pure override returns (uint16) {
        return 1;
    }

    /// @notice returns the owner of strategy pool
    function owner() public view override(URUSCore, IERC5313) returns (address) {
        try poolsNFT.ownerOf(poolId) returns (address _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice sweep tokens from smart contract
    /// @param token address of token to sweep
    function sweep(address token, address to) public payable {
        _onlyOwner();
        if (
            token == address(getAToken(baseToken)) ||
            token == address(getAToken(quoteToken))
        ) {
            revert CantSweepYieldToken();
        }
        uint256 _balance;
        if (token == address(0)) {
            _balance = address(this).balance;
            if (_balance == 0) {
                revert ZeroETH();
            }
            (bool success, ) = payable(to).call{value: _balance}("");
            if (!success) {
                revert FailETHTransfer();
            }
        } else {
            _balance = IToken(token).balanceOf(address(this));
            if (_balance == 0) {
                revert FailTokenTransfer();
            }
            IToken(token).safeTransfer(to, _balance);
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
        return investedAmount[quoteToken];
    }

    /// @notice returns base token amount
    function getBaseTokenAmount() public view override returns (uint256) {
        return investedAmount[baseToken];
    }

}