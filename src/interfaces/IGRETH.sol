// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "src/interfaces/IToken.sol";

interface IGRETH is IToken {
    error NotGrindURUSPoolsNFT();
    error NotGrindURUSOwner();
    error InvalidLength();

    function grindURUSPoolsNFT() external view returns (address);

    function totalGrinds() external view returns (uint256);

    function mint(
        address[] memory actors,
        uint256[] memory rewards
    ) external returns (uint256 totalReward);
}
