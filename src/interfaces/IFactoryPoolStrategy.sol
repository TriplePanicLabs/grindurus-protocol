// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT} from "./IPoolsNFT.sol";
import {IPoolStrategy} from "./IPoolStrategy.sol";

interface IFactoryPoolStrategy {
    error NotGrindurusPoolsNFT();
    error InvalidStrategyId();
    error NotOwner();

    function poolsNFT() external view returns (IPoolsNFT);

    function deploy(
        uint256 _poolId,
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _quoteToken,
        address _baseToken
    ) external returns (address);

    function owner() external view returns (address);

    function strategyId() external pure returns (uint16);
}
