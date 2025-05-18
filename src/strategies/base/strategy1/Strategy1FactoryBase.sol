// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { Strategy1Base } from "./Strategy1Base.sol";
import { StrategyFactory, IURUS } from "src/strategies/StrategyFactory.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of Strategy1 on Base
contract Strategy1FactoryBase is StrategyFactory {

    address public oracleWethUsdBase;
    address public wethBase;
    address public usdcBase;

    address public aaveV3PoolBase;
    address public uniswapV3SwapRouterBase;

    /// @dev quoteToken => baseToken => uniswapV3PoolFee
    mapping (address quoteToken => mapping(address baseToken => uint24)) public uniswapV3PoolFee;

    /// @param _poolsNFT address of PoolsNFT
    /// @param _registry address of registry
    constructor(address _poolsNFT, address _registry, address initialStrategyImplementation) StrategyFactory(_poolsNFT, _registry, initialStrategyImplementation) {
        oracleWethUsdBase = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // chainlink WETH/USD oracle;
        wethBase = 0x4200000000000000000000000000000000000006;
        usdcBase = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        aaveV3PoolBase = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
        uniswapV3SwapRouterBase = 0x2626664c2603336E57B271c5C0b26F421741e481;

        uniswapV3PoolFee[usdcBase][wethBase] = 100;
        uniswapV3PoolFee[wethBase][usdcBase] = 100;

        feeToken = wethBase;
    }

    /// @notice sets aave v3 pool
    /// @param _aaveV3Pool address of aave v3 pool
    function setAAVEV3Pool(address _aaveV3Pool) public {
        _onlyOwner();
        aaveV3PoolBase = _aaveV3Pool;
    }

    /// @notice sets uniswap V3 swap rourer
    /// @param _swapRouter address of swap router
    function setUniswapV3SwapRouter(address _swapRouter) public {
        _onlyOwner();
        uniswapV3SwapRouterBase = _swapRouter;
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
        address baseToken,
        address quoteToken,
        IURUS.Config memory config
    ) public override returns (address) {
        _onlyGateway();
        if (isZeroConfig(config)) {
            config = getDefaultConfig();
        }
        Strategy1Base pool = Strategy1Base(_deploy());
        address oracleQuoteTokenPerFeeToken = registry.getOracle(quoteToken, feeToken); // may be address(0)
        address oracleQuoteTokenPerBaseToken = registry.getOracle(quoteToken, baseToken); //  may be address(0)
        bytes memory lendingArgs = pool.encodeLendingConstructorArgs(aaveV3PoolBase);
        bytes memory dexArgs = pool.encodeDexConstructorArgs(
            uniswapV3SwapRouterBase,
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
