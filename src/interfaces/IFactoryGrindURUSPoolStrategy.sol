// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IGrindURUSPoolStrategy} from "./IGrindURUSPoolStrategy.sol";

interface IFactoryGrindURUSPoolStrategy {
    error NotGrindurusPoolsNFT();
    error InvalidStrategyId(uint256 poolStrategyId, uint256 factoryStrategyId);

    function deploy(
        uint256 _poolId,
        address _oracleQuoteTokenPerFeeToken,
        address _oracleQuoteTokenPerBaseToken,
        address _feeToken,
        address _baseToken,
        address _quoteToken
    ) external returns (address);

    function strategyId() external pure returns (uint16);
}
