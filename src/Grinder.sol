// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {Ownable2Step, Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract Grinder is Ownable2Step {

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

    constructor (address _poolsNFT) Ownable(msg.sender) {
        if (_poolsNFT == address(0)) { 
            poolsNFT = IPoolsNFT(msg.sender);
        } else {
            poolsNFT = IPoolsNFT(_poolsNFT);
        }
    }

    function grind(uint256 poolId) public {
        poolsNFT.grind(poolId);
        /// any operation;
    }

    function batchGrind(uint256[] memory poolIds) public {
        uint256 len = poolIds.length;
        for (uint256 i = 0; i < len; ) {
            poolsNFT.grind(poolIds[i]);
            unchecked { ++i; }
        }
    }

    function execute(address target, uint256 value, bytes calldata data) external returns (bool success) {
        (success, ) = target.call{value: value}(data);
    }

}