// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IPoolsNFT } from "./IPoolsNFT.sol";
import { IStrategy, IURUS } from "./IStrategy.sol";

interface IStrategyFactory {

    error NotOwner();
    error NotGateway();

    function poolsNFT() external view returns (IPoolsNFT);

    function deploy(
        uint256 poolId,
        address baseToken,
        address quoteToken,
        IURUS.Config memory config
    ) external returns (address);

    function isZeroConfig(IURUS.Config memory config) external pure returns (bool);

    function owner() external view returns (address);

    function getZeroConfig() external pure returns (IURUS.Config memory);

    function getDefaultConfig() external view returns (IURUS.Config memory);

    function strategyId() external pure returns (uint16);

    function execute(address target, uint256 value, bytes calldata data) external returns (bool success, bytes memory result);
    
}
