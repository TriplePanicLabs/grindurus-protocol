// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

interface IGRAI is IOFT {

    error NotGrinderAI();

    function mint(address to, uint256 amount) external; 

}