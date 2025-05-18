// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IStrategyFactory } from "src/interfaces/IStrategyFactory.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IURUS } from "src/interfaces/IURUS.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { ERC1967Proxy } from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title StragegyFactory
contract StrategyFactory is IStrategyFactory {

    /// @dev address of grindurus pools NFT
    IPoolsNFT public poolsNFT;

    /// @dev default config for strategyV1
    IURUS.Config public defaultConfig;

    /// @dev address of fee token
    address public feeToken;

    /// @dev addess of oracle registry
    IRegistry public registry;

    /// @dev address of implementation of strategy1
    address public strategyImplementation;

    /// @param _poolsNFT address of PoolsNFT
    /// @param _registry address of registry
    /// @param initialStrategyImplementation initial strategy implementation
    constructor(address _poolsNFT, address _registry, address initialStrategyImplementation) {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT = IPoolsNFT(msg.sender);
        }
        registry = IRegistry(_registry);
        strategyImplementation = initialStrategyImplementation;
        defaultConfig = IURUS.Config({
            // maxLiquidity = initLiquidity * (extraCoef + 1) ** (longNumberMax - 1)
            longNumberMax: 3,
            hedgeNumberMax: 3,
            extraCoef: 2_00, // x2.00
            priceVolatilityPercent: 1_00, // 1%
            returnPercentLongSell: 100_50, // 100.50% // returnPercent = (amountInvested + profit) * 100 / amountInvested
            returnPercentHedgeSell: 100_50, // 100.50%
            returnPercentHedgeRebuy: 100_50 // 100.50%
        });
    }

    /// @dev checks that msg.sender is gateway
    function _onlyGateway() internal view virtual {
        if (msg.sender != address(poolsNFT)) {
            revert NotGateway();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view virtual {
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
    ) public override virtual returns (address) {}

    /// @notice deploy proxy of strategy implementation
    function _deploy() internal virtual returns (address payable) {
        ERC1967Proxy proxy = new ERC1967Proxy(strategyImplementation, "");
        return payable(proxy);
    }

    /// @notice returns if config is zero config
    function isZeroConfig(IURUS.Config memory config) public pure returns (bool) {
        return 
            config.longNumberMax == 0 &&
            config.hedgeNumberMax == 0 &&
            config.extraCoef == 0 &&
            config.priceVolatilityPercent == 0 &&
            config.returnPercentLongSell == 0 &&
            config.returnPercentHedgeSell == 0 && 
            config.returnPercentHedgeRebuy == 0;
    }

    /// @notice returns address of owner
    function owner() public view returns (address) {
        try IPoolsNFT(poolsNFT).owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice returns zero config
    function getZeroConfig() public pure override returns (IURUS.Config memory) {
        return IURUS.Config({
            longNumberMax: 0,
            hedgeNumberMax: 0,
            extraCoef: 0,
            priceVolatilityPercent: 0,
            returnPercentLongSell: 0,
            returnPercentHedgeSell: 0,
            returnPercentHedgeRebuy: 0
        });
    }

    /// @notice returns default config
    function getDefaultConfig() public view override returns (IURUS.Config memory) {
        return defaultConfig;
    }

    /// @notice return strategy id
    function strategyId() public pure virtual returns (uint16) {
        return type(uint8).max;
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