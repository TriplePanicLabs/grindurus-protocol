// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IFactoryPoolStrategy} from "src/interfaces/IFactoryPoolStrategy.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {PoolStrategy1, IPoolStrategy, IToken} from "src/strategy1/PoolStrategy1.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of strategyV1
contract FactoryPoolStrategy1 is IFactoryPoolStrategy {
    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IPoolStrategy.Config public defaultConfig;

    // address public oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address private wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address private aaveV3PoolArbitrum = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address private uniswapV3SwapRouterArbitrum = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

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
        defaultConfig = IPoolStrategy.Config({
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
    }

    /// @notice checks that msg.sender is poolsNFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != address(poolsNFT)) {
            revert NotGrindurusPoolsNFT();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets average price volatility
    /// @param quoteToken address of quoteToken
    /// @param baseToken address of baseToken
    /// @param _averagePriceVolatility price scaled by 10**8
    /// @param _uniswapV3PoolFee  uniswap pool fee
    function setDefaultStrategyParams(
        address quoteToken,
        address baseToken,
        uint256 _averagePriceVolatility,
        uint24 _uniswapV3PoolFee
    ) public {
        _onlyOwner();
        averagePriceVolatility[quoteToken][baseToken] = _averagePriceVolatility;
        uniswapV3PoolFee[quoteToken][baseToken] = _uniswapV3PoolFee;
    }

    /// @notice sets average price volatility
    /// @param quoteToken address of quoteToken
    /// @param baseToken address of baseToken
    /// @param _averagePriceVolatility price scaled by 10**8
    function setAveragePriceVolatility(
        address quoteToken,
        address baseToken,
        uint256 _averagePriceVolatility
    ) public {
        _onlyOwner();
        averagePriceVolatility[quoteToken][baseToken] = _averagePriceVolatility;
    }

    /// @notice sets uniswapV3 fee
    /// @param quoteToken address of quoteToken
    /// @param baseToken address of baseToken
    /// @param _uniswapV3PoolFee price scaled by 10**8
    function setUniswapV3PoolFee(
        address quoteToken,
        address baseToken,
        uint24 _uniswapV3PoolFee
    ) public {
        _onlyOwner();
        uniswapV3PoolFee[quoteToken][baseToken] = _uniswapV3PoolFee;
    }

    /// @notice deploy strategy pool
    /// @param poolId id of pool
    /// @param oracleQuoteTokenPerFeeToken oracle address
    /// @param oracleQuoteTokenPerBaseToken oracle address
    /// @param feeToken address of fee token (ETH)
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    /// @return pool address of pool
    function deploy(
        uint256 poolId,
        address oracleQuoteTokenPerFeeToken,
        address oracleQuoteTokenPerBaseToken,
        address feeToken,
        address quoteToken,
        address baseToken
    ) public override returns (address) {
        _onlyPoolsNFT();
        PoolStrategy1 pool = new PoolStrategy1();
        uint24 uniswapV3Fee = uniswapV3PoolFee[quoteToken][baseToken];
        pool.init(
            address(poolsNFT),
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            quoteToken,
            baseToken,
            abi.encode(aaveV3PoolArbitrum),
            abi.encode(
                uniswapV3SwapRouterArbitrum,
                uniswapV3Fee
            ),
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
        return 1;
    }
}
