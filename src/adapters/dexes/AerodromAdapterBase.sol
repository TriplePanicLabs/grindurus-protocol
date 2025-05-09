// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "src/interfaces/IDexAdapter.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AerodromeAdapterBase is IDexAdapter {
    using SafeERC20 for IToken;

    uint256 private _arg = 0;

    function _swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {

    }

    /// @notice return dex params
    function getDexParams() public view virtual override returns (bytes memory args) {
        args = abi.encode(_arg);
    }

    /// @notice set dex params
    function setDexParams(bytes memory args) public virtual override {
        (uint256 arg) = abi.decode(args, (uint256));
        arg++;
    }

}