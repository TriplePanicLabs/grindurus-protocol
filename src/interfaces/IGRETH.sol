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
    error ZeroTokenAmount();
    error FailTransferETH();

    event Mint(address[] actors, uint256[] shares, uint256 minted);
    event Burn(address burner, uint256 amount, address token, uint256 tokenAmount);

    function poolsNFT() external view returns (address);

    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) external returns (uint256 totalShares);

    function burn(uint256 amount, address token) external payable returns (uint256 tokenAmount);

    function share(uint256 amount, address token) external view returns (uint256);

}
