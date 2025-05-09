// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IToken } from "./IToken.sol";
import { IPoolsNFT } from "./IPoolsNFT.sol";
import { IURUS } from "src/interfaces/IURUS.sol";
import { IDexAdapter } from "src/interfaces/IDexAdapter.sol";
import { ILendingAdapter } from "src/interfaces/ILendingAdapter.sol"; 

/// @notice the interface for Strategy Pool
interface IStrategy is IURUS, IDexAdapter, ILendingAdapter {

    error NotOwner();
    error NotAgent();
    error NotGateway();

    function poolsNFT() external view returns (IPoolsNFT);

    function poolId() external view returns (uint256);

    function reinvest() external view returns (bool);

    function switchReinvest() external;

    function ROI() external view returns (uint256 ROINumerator, uint256 ROIDenominator, uint256 ROIPeriod);

    function getActiveCapital() external view returns (uint256);

    function strategyId() external view returns (uint16);

    function getQuoteToken() external view returns (IToken);

    function getBaseToken() external view returns (IToken);

    function getQuoteTokenAmount() external view returns (uint256);

    function getBaseTokenAmount() external view returns (uint256);

}
