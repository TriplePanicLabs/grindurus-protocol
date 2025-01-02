// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT} from "./IPoolsNFT.sol";
import {IStrategy} from "./IStrategy.sol";

interface IStrategyFactory {
    error NotPoolsNFT();
    error InvalidStrategyId();
    error InvalidOracleFeeToken();
    error InvalidOracleBaseToken();
    error NotOwner();

    function poolsNFT() external view returns (IPoolsNFT);

    function deploy(
        uint256 _poolId,
        address _quoteToken,
        address _baseToken
    ) external returns (address);

    function owner() external view returns (address);

    function strategyId() external pure returns (uint16);
}
