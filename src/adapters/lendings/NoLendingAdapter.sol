// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ILendingAdapter, IToken} from "src/interfaces/ILendingAdapter.sol";

/// @title NoLendingAdapter
/// @notice No adapter to lending protocol. Just store funds on this contract
contract NoLendingAdapter is ILendingAdapter {

    /// @dev address of token => store amount
    mapping (IToken token => uint256) public investedAmount;

    function _put(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 putAmount) {
        putAmount = amount;
        investedAmount[token] += putAmount;
    }

    function _take(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 takeAmount) {
        takeAmount = amount;
        if (takeAmount > investedAmount[token]) {
            takeAmount = investedAmount[token];
        }
        investedAmount[token] -= takeAmount;
    }

    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal virtual {}

    function getPendingYield(IToken token) public view virtual override returns (uint256) {
        token;
        return 0;
    }

}