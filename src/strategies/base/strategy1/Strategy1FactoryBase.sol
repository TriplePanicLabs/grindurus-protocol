// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IStrategyFactory} from "src/interfaces/IStrategyFactory.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {Strategy1Base, IStrategy, IToken} from "./Strategy1Base.sol";
import {IURUS} from "src/interfaces/IURUS.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title GrindURUS Factory Pool Strategy 1
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice factory, that is responsible for deployment of Strategy1 on Base
contract Strategy1FactoryBase is IStrategyFactory {
    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IURUS.Config public defaultConfig;

    address internal oracleWethUsdBase;
    address internal wethBase;
    address internal usdcBase;

    address public aaveV3PoolBase;
    address public uniswapV3SwapRouterBase;

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
            longNumberMax: 3,
            hedgeNumberMax: 3,
            priceVolatilityPercent: 1_00, // 1%
            extraCoef: 2_00, // x2.00
            returnPercentLongSell: 100_50, // 100.50% // returnPercent = (amountInvested + profit) * 100 / amountInvested
            returnPercentHedgeSell: 100_50, // 100.50%
            returnPercentHedgeRebuy: 100_50 // 100.50%
        });

        oracleWethUsdBase = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // chainlink WETH/USD oracle;
        wethBase = 0x4200000000000000000000000000000000000006;
        usdcBase = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        aaveV3PoolBase = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
        uniswapV3SwapRouterBase = 0x2626664c2603336E57B271c5C0b26F421741e481;

        uniswapV3PoolFee[usdcBase][wethBase] = 100;

        feeToken = wethBase;
    }

    /// @dev checks that msg.sender is gateway
    function _onlyGateway() internal view virtual {
        if (msg.sender != address(poolsNFT)) {
            revert NotGateway();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
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
        address quoteToken
    ) public override returns (address) {
        _onlyGateway();
        address oracleQuoteTokenPerFeeToken = registry.getOracle(quoteToken, feeToken); // may be address(0)
        address oracleQuoteTokenPerBaseToken = registry.getOracle(quoteToken, baseToken); // may be address(0)
        Strategy1Base pool = Strategy1Base(_deploy());
        uint24 uniswapV3Fee = uniswapV3PoolFee[quoteToken][baseToken];
        bytes memory lendingArgs = abi.encode(aaveV3PoolBase);
        bytes memory dexArgs = abi.encode(uniswapV3SwapRouterBase, uniswapV3Fee, quoteToken, baseToken);
        
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

    /// @notice execute any transaction
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    /// @return success true if transaction was successful
    /// @return result data returned from target contract
    function execute(address target, uint256 value, bytes calldata data) public override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }
}
