// SPDX-License-Identifier: Apache-2.0

pragma solidity >0.6.11;

import {IToken} from "./IToken.sol";

interface IWETH9 is IToken {
    function deposit() external payable;

    function withdraw(uint256 _amount) external;
}