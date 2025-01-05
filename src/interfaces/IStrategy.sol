// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";
import {IPoolsNFT} from "./IPoolsNFT.sol";
import {IURUSCore} from "src/interfaces/IURUSCore.sol";

/// @notice the interface for Strategy Pool
interface IStrategy is IURUSCore {
    error StrategyInitialized(uint256 strategyId);

    function poolsNFT() external view returns (IPoolsNFT);

    function poolId() external view returns (uint256);

    function ROI() external view returns (uint256 ROINumerator, uint256 ROIDenominator, uint256 ROIPeriod);

    function APR() external view returns (uint256 APRNumerator, uint256 APRDenominator);

    function getActiveCapital() external view returns (uint256);

    function strategyId() external view returns (uint16);

    function getQuoteToken() external view returns (IToken);

    function getBaseToken() external view returns (IToken);

    function getQuoteTokenAmount() external view returns (uint256);

    function getBaseTokenAmount() external view returns (uint256);

}
