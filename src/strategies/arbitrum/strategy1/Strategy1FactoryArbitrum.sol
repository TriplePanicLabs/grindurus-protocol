// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { Strategy1Arbitrum } from "./Strategy1Arbitrum.sol";
import { StrategyFactory, IURUS } from "src/strategies/StrategyFactory.sol";

/// @title GrindURUS Strategy1 Factory
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of Strategy1 on Arbitrum
contract Strategy1FactoryArbitrum is StrategyFactory {

    address public oracleWethUsdArbitrum;
    address public wethArbitrum;
    address public usdtArbitrum;
    address public usdcArbitrum;

    address public aaveV3PoolArbitrum;
    address public uniswapV3SwapRouterArbitrum;

    /// @dev quoteToken => baseToken => uniswapV3PoolFee
    mapping (address quoteToken => mapping(address baseToken => uint24)) public uniswapV3PoolFee;

    /// @param _poolsNFT address of PoolsNFT
    /// @param _registry address of registry
    constructor(address _poolsNFT, address _registry, address initialStrategyImplementation) StrategyFactory(_poolsNFT, _registry, initialStrategyImplementation) {
        oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // chainlink WETH/USD oracle;
        wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        aaveV3PoolArbitrum = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
        uniswapV3SwapRouterArbitrum = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

        uniswapV3PoolFee[usdtArbitrum][wethArbitrum] = 100;
        uniswapV3PoolFee[wethArbitrum][usdtArbitrum] = 100;
        uniswapV3PoolFee[usdcArbitrum][wethArbitrum] = 100;
        uniswapV3PoolFee[wethArbitrum][usdcArbitrum] = 100;

        feeToken = wethArbitrum;
    }

    /// @notice sets aave v3 pool
    /// @param _aaveV3Pool address of aave v3 pool
    function setAAVEV3Pool(address _aaveV3Pool) public {
        _onlyOwner();
        aaveV3PoolArbitrum = _aaveV3Pool;
    }

    /// @notice sets uniswap V3 swap rourer
    /// @param _swapRouter address of swap router
    function setUniswapV3SwapRouter(address _swapRouter) public {
        _onlyOwner();
        uniswapV3SwapRouterArbitrum = _swapRouter;
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
        uniswapV3PoolFee[baseToken][quoteToken] = _uniswapV3PoolFee;
    }

    /// @notice deploy strategy pool
    /// @param poolId id of pool
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    /// @return pool address of pool
    function deploy(
        uint256 poolId,
        address baseToken,
        address quoteToken,
        IURUS.Config memory config
    ) public override returns (address) {
        _onlyGateway();
        if (isZeroConfig(config)) {
            config = getDefaultConfig();
        }
        Strategy1Arbitrum pool = Strategy1Arbitrum(_deploy());
        address oracleQuoteTokenPerFeeToken = registry.getOracle(quoteToken, feeToken); // may be address(0)
        address oracleQuoteTokenPerBaseToken = registry.getOracle(quoteToken, baseToken); //  may be address(0)
        bytes memory lendingArgs = pool.encodeLendingConstructorArgs(aaveV3PoolArbitrum);
        bytes memory dexArgs = pool.encodeDexConstructorArgs(
            uniswapV3SwapRouterArbitrum,
            uniswapV3PoolFee[quoteToken][baseToken],
            baseToken,
            quoteToken
        );
        pool.init(
            address(poolsNFT),
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            config,
            lendingArgs,
            dexArgs
        );
        return address(pool);
    }

    /// @notice returns strategy id of factory
    function strategyId() public pure override returns (uint16) {
        return 1;
    }

}
