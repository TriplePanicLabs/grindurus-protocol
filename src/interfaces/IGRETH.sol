// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";

interface IGRETH is IToken {
    error NotPoolsNFT();
    error NotOwner();
    error InvalidLength();
    error InvalidAmount();
    error AmountExceededSupply();
    error ZeroTokenAmount();
    error FailTransferETH();

    event Mint(address[] actors, uint256[] shares, uint256 minted);
    event Burn(address burner, uint256 amount, address token, uint256 tokenAmount);

    function poolsNFT() external view returns (IPoolsNFT);

    function totalGrinded() external view returns (uint256);

    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) external returns (uint256 totalShares);

    function burn(uint256 amount, address token) external payable returns (uint256 tokenAmount);

    function batchBurn(uint256[] memory amounts, address[] memory tokens) external payable returns (uint256 tokenAmount);

    function share(uint256 amount, address token) external view returns (uint256);

    function owner() external view returns (address);

}
