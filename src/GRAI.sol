// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";
import { IGrinderAI } from "src/interfaces/IGrinderAI.sol";

/// @notice GrinderAI ERC20 token
contract GRAI is IGRAI, OFT {

    /// @dev address of grinderAI 
    IGrinderAI public grinderAI;

    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("GrinderAI Token", "grAI", _lzEndpoint, _delegate) Ownable(_delegate) {
        grinderAI = IGrinderAI(_delegate);
    }

    /// @notice check that msg.sender is grinderAI
    function _onlyGrinderAI() private view {
        if (msg.sender != address(grinderAI)) {
            revert NotGrinderAI();
        }
    }

    /// @notice mints amount of grAI to `to`
    /// @param to address to mint to
    /// @param amount amount of grAI to mint
    function mint(address to, uint256 amount) public {
        _onlyGrinderAI();
        _mint(to, amount);
    }

}