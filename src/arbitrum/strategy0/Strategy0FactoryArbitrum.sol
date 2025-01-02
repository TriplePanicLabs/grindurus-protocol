// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IStrategyFactory} from "src/interfaces/IStrategyFactory.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {Strategy0Arbitrum, IStrategy, IToken} from "src/arbitrum/strategy0/Strategy0Arbitrum.sol";
import {IURUSCore} from "src/interfaces/IURUSCore.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of Strategy1 on Arbitrum
contract Strategy0FactoryArbitrum is IStrategyFactory {
    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IURUSCore.Config public defaultConfig;

    address private oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // chainlink WETH/USD oracle;
    address private wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address private uniswapV3SwapRouterArbitrum = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /// @dev address of fee token
    address public feeToken;

    /// @dev quote token => oracle address
    mapping (address quoteToken => address) public oracleQuoteTokenPerFeeToken;

    /// @dev quote token => base token => oracle address
    mapping (address quoteToken => mapping(address baseToken => address)) public oracleQuoteTokenPerBaseToken;

    /// @dev quoteToken => baseToken => averagePriceVolatility
    mapping (address quoteToken => mapping(address baseToken => uint256)) public averagePriceVolatility;

    /// @dev quoteToken => baseToken => uniswapV3PoolFee
    mapping (address quoteToken => mapping(address baseToken => uint24)) public uniswapV3PoolFee;

    constructor(address _poolsNFT) {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT = IPoolsNFT(msg.sender);
        }
        defaultConfig = IURUSCore.Config({
            // maxLiquidity = initLiquidity * (extraCoef + 1) ** (longNumberMax - 1)
            longNumberMax: 4,
            hedgeNumberMax: 4,
            averagePriceVolatility: 30 * (10 ** 8),
            extraCoef: 2_00, // x2.00
            returnPercentLongSell: 100_50, // 100.50% // returnPercent = (amountInvested + profit) * 100 / amountInvested
            returnPercentHedgeSell: 100_50, // 100.50%
            returnPercentHedgeRebuy: 100_50 // 100.50%
        });
        averagePriceVolatility[usdtArbitrum][wethArbitrum] = 30 * (10 ** 8);
        uniswapV3PoolFee[usdtArbitrum][wethArbitrum] = 500;

        feeToken = wethArbitrum;
        oracleQuoteTokenPerFeeToken[usdtArbitrum] = oracleWethUsdArbitrum;
        oracleQuoteTokenPerFeeToken[usdcArbitrum] = oracleWethUsdArbitrum;
        oracleQuoteTokenPerBaseToken[usdtArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
        oracleQuoteTokenPerBaseToken[usdcArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
    }

    /// @notice checks that msg.sender is poolsNFT
    function _onlyPoolsNFT() internal view {
        if (msg.sender != address(poolsNFT)) {
            revert NotPoolsNFT();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets fee token oracle for quote token
    /// @param _quoteToken address of quote token
    /// @param _oracle address of oracle
    function setOracleQuoteTokenPerFeeToken(address _quoteToken, address _oracle) public {
        _onlyOwner();
        oracleQuoteTokenPerFeeToken[_quoteToken] = _oracle;
    }

    /// @notice set base token oracle for quote token
    /// @param _quoteToken address of quote token
    /// @param _baseToken address of quote token
    /// @param _oracle address of oracle
    function setOracleQuoteTokenPerBaseToken(address _quoteToken, address _baseToken, address _oracle) public {
        _onlyOwner();
        oracleQuoteTokenPerBaseToken[_quoteToken][_baseToken] = _oracle;
    }

    /// @notice sets average price volatility
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    /// @param _averagePriceVolatility price scaled by 10**8
    /// @param _uniswapV3PoolFee  uniswap pool fee
    function setDefaultStrategyParams(
        address _quoteToken,
        address _baseToken,
        uint256 _averagePriceVolatility,
        uint24 _uniswapV3PoolFee
    ) public {
        _onlyOwner();
        averagePriceVolatility[_quoteToken][_baseToken] = _averagePriceVolatility;
        uniswapV3PoolFee[_quoteToken][_baseToken] = _uniswapV3PoolFee;
    }

    /// @notice sets average price volatility
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    /// @param _averagePriceVolatility price scaled by 10**8
    function setAveragePriceVolatility(
        address _quoteToken,
        address _baseToken,
        uint256 _averagePriceVolatility
    ) public {
        _onlyOwner();
        averagePriceVolatility[_quoteToken][_baseToken] = _averagePriceVolatility;
    }

    /// @notice sets uniswapV3 fee
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    /// @param _uniswapV3PoolFee price scaled by 10**8
    function setUniswapV3PoolFee(
        address _quoteToken,
        address _baseToken,
        uint24 _uniswapV3PoolFee
    ) public {
        _onlyOwner();
        uniswapV3PoolFee[_quoteToken][_baseToken] = _uniswapV3PoolFee;
    }

    /// @notice deploy strategy pool
    /// @param poolId id of pool
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    /// @return pool address of pool
    function deploy(
        uint256 poolId,
        address quoteToken,
        address baseToken
    ) public override returns (address) {
        _onlyPoolsNFT();
        if (oracleQuoteTokenPerFeeToken[quoteToken] == address(0)) {
            revert InvalidOracleFeeToken();
        }
        if (oracleQuoteTokenPerBaseToken[quoteToken][baseToken] == address(0)) {
            revert InvalidOracleBaseToken();
        }
        Strategy0Arbitrum pool = new Strategy0Arbitrum();
        uint24 uniswapV3Fee = uniswapV3PoolFee[quoteToken][baseToken];
        bytes memory dexArgs = abi.encode(uniswapV3SwapRouterArbitrum, uniswapV3Fee, quoteToken, baseToken);
        pool.init(
            address(poolsNFT),
            poolId,
            oracleQuoteTokenPerFeeToken[quoteToken],
            oracleQuoteTokenPerBaseToken[quoteToken][baseToken],
            wethArbitrum, // fee token
            quoteToken,
            baseToken,
            dexArgs,
            defaultConfig
        );
        return address(pool);
    }

    /// @notice returns address of owner
    function owner() public view returns (address) {
        try IPoolsNFT(poolsNFT).owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice returns strategy id of factory
    function strategyId() public pure override returns (uint16) {
        return 0;
    }
}
