

// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ISwapRouterArbitrum} from 'src/interfaces/uniswapV3/ISwapRouterArbitrum.sol';
import {IToken} from 'src/interfaces/IToken.sol';
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    using SafeERC20 for IToken;

    constructor (string memory name_, string memory symbol_) ERC20(name_, symbol_) {} 

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}