// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "src/interfaces/IToken.sol";

interface IGRETH is IToken {
    error NotGrindURUSPoolsNFT();
    error NotGrindURUSOwner();
    error InvalidLength();
    error NotOwner();
    error InvalidAmount();
    error AmountExceededSupply();

    function poolsNFT() external view returns (address);

    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) external returns (uint256 totalShares);

    function burn(uint256 amount, address token) external payable;

    function share(uint256 amount, address token) external view returns (uint256);

}
