// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";

interface ILendingAdapter {
    error FailPut(address token, uint256 amount);
    error FailTake(address token, uint256 amount);

    function put(IToken token, uint256 amount) external returns (uint256 poolTokenAmount, uint256 putAmount);

    function take(IToken token, uint256 amount) external returns (uint256 poolTokenAmount, uint256 putAmount);

    function harvest(IToken token) external returns (uint256 harvestedYield);

    function getPendingYield(IToken token) external view returns (uint256);
}
