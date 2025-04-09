// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT} from "./IPoolsNFT.sol";
import {IStrategy} from "./IStrategy.sol";

interface IStrategyFactory {

    function poolsNFT() external view returns (IPoolsNFT);

    function deploy(
        uint256 poolId,
        address baseToken,
        address quoteToken
    ) external returns (address);

    function owner() external view returns (address);

    function strategyId() external pure returns (uint16);

    function execute(address target, uint256 value, bytes calldata data) external returns (bool success, bytes memory result);
    
}
