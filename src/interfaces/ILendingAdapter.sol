// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "./IToken.sol";

interface ILendingAdapter {
    error LendingInitialized();

    function put(
        IToken token,
        uint256 amount
    ) external returns (uint256 putAmount);

    function take(
        IToken token,
        uint256 amount
    ) external returns (uint256 takeAmount);

    function getPendingYield(IToken token) external view returns (uint256);
}
