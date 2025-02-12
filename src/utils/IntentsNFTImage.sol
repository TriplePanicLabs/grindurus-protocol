// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IIntentsNFTImage} from "src/interfaces/IIntentsNFTImage.sol";

contract IntentsNFTImage is IIntentsNFTImage {

    IPoolsNFT public poolsNFT;

    constructor (address _poolsNFT) {
        poolsNFT = IPoolsNFT(_poolsNFT);
    }

    function URI(uint256 poolId) public view returns (string memory) {

    }

}