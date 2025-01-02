// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ILendingAdapter, IToken} from "../../interfaces/ILendingAdapter.sol";

/// @title NoLendingAdapter
/// @notice No adapter to lending protocol. Just store funds on this contract
contract NoLendingAdapter is ILendingAdapter {

    function _onlyOwner() internal view virtual {}

    function put(
        IToken token,
        uint256 amount
    ) public override virtual returns (uint256 putAmount) {
        token; amount; putAmount; // not designed to direct take. Use _put(...)
        revert();
    }

    function take(
        IToken token,
        uint256 amount
    ) public override virtual returns (uint256 takeAmount) {
        token; amount; takeAmount;
        revert(); // not designed to direct take. Use _take(...)
    }

    function _put(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 putAmount) {
        token;
        putAmount = amount;
    }

    function _take(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 takeAmount) {
        token;
        takeAmount = amount;
    }

    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal virtual {}

    function getPendingYield(IToken token) public override pure returns (uint256) {
        token;
        return 0;
    }

}