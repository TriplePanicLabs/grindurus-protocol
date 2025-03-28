// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IStrategyFactory} from "src/interfaces/IStrategyFactory.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {Strategy1Arbitrum, IStrategy, IToken} from "./Strategy1Arbitrum.sol";
import {IURUS} from "src/interfaces/IURUS.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of Strategy1 on Arbitrum
contract Strategy1FactoryArbitrum is IStrategyFactory {
    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IURUS.Config public defaultConfig;

    address private oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // chainlink WETH/USD oracle;
    address private wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public aaveV3PoolArbitrum = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public uniswapV3SwapRouterArbitrum = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /// @dev address of fee token
    address public feeToken;

    /// @dev addess of oracle registry
    IRegistry public registry;

    /// @dev address of implementation of strategy1
    address public strategyImplementation;

    /// @dev quoteToken => baseToken => uniswapV3PoolFee
    mapping (address quoteToken => mapping(address baseToken => uint24)) public uniswapV3PoolFee;

    /// @param _poolsNFT address of PoolsNFT
    /// @param _registry address of registry
    constructor(address _poolsNFT, address _registry) {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT = IPoolsNFT(msg.sender);
        }
        registry = IRegistry(_registry);
        defaultConfig = IURUS.Config({
            // maxLiquidity = initLiquidity * (extraCoef + 1) ** (longNumberMax - 1)
            longNumberMax: 4,
            hedgeNumberMax: 4,
            priceVolatilityPercent: 1_00, // 1%
            extraCoef: 2_00, // x2.00
            returnPercentLongSell: 100_50, // 100.50% // returnPercent = (amountInvested + profit) * 100 / amountInvested
            returnPercentHedgeSell: 100_50, // 100.50%
            returnPercentHedgeRebuy: 100_50 // 100.50%
        });
        uniswapV3PoolFee[usdtArbitrum][wethArbitrum] = 100;
        uniswapV3PoolFee[usdcArbitrum][wethArbitrum] = 100;

        feeToken = wethArbitrum;
    }

    /// @notice checks that msg.sender is poolsNFT
    function _onlyPoolsNFT() internal view {
        require(msg.sender == address(poolsNFT));
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        require(msg.sender == owner());
    }

    /// @notice sets strategy implementation
    function setStrategyImplementation(address _stategyImplementation) external {
        _onlyOwner();
        strategyImplementation = _stategyImplementation;
    }

    /// @notice sets default config
    /// @param config new filled config
    function setDefaultConfig(IURUS.Config memory config) external {
        _onlyOwner();
        defaultConfig = config;
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
        address quoteToken
    ) public override returns (address) {
        _onlyPoolsNFT();
        address oracleQuoteTokenPerFeeToken = registry.getOracle(quoteToken, feeToken); // may be address(0)
        address oracleQuoteTokenPerBaseToken = registry.getOracle(quoteToken, baseToken); // may be address(0)
        Strategy1Arbitrum pool = Strategy1Arbitrum(_deploy());
        uint24 uniswapV3Fee = uniswapV3PoolFee[quoteToken][baseToken];
        bytes memory lendingArgs = abi.encode(aaveV3PoolArbitrum);
        bytes memory dexArgs = abi.encode(uniswapV3SwapRouterArbitrum, uniswapV3Fee, quoteToken, baseToken);
        
        pool.init(
            address(poolsNFT),
            poolId,
            oracleQuoteTokenPerFeeToken,
            oracleQuoteTokenPerBaseToken,
            feeToken,
            baseToken,
            quoteToken,
            defaultConfig,
            lendingArgs,
            dexArgs
        );
        return address(pool);
    }

    /// @notice deploy proxy of strategy implementation
    function _deploy() internal returns (address payable) {
        ERC1967Proxy proxy = new ERC1967Proxy(strategyImplementation, "");
        return payable(proxy);
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
