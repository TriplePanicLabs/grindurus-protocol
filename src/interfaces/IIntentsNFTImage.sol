// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IIntentsNFTImage {

    function URI(uint256 poolId) external view returns (string memory);

}