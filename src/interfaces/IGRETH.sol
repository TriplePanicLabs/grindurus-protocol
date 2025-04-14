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
    error FailMint();
    error Forbid();
    error ZeroTokenAmount();
    error FailTransferETH();

    event Mint(address[] actors, uint256[] shares, uint256 minted);
    event Burn(address burner, uint256 amount, address token, uint256 tokenAmount);
    event CallResult(bytes result);

    function poolsNFT() external view returns (IPoolsNFT);

    function totalGrinded() external view returns (uint256);

    function mint() external payable returns (uint256 mintedAmount);

    function mintTo(address receiver) external payable returns (uint256 mintedAmount);

    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) external returns (uint256 totalShares);

    function burn(uint256 amount) external returns (uint256 tokenAmount);

    function burn(uint256 amount, address token) external payable returns (uint256 tokenAmount);

    function burnTo(uint256 amount, address token, address to) external payable returns (uint256 tokenAmount);

    function batchBurn(uint256[] memory amounts, address[] memory tokens) external payable returns (uint256[] memory);

    function batchBurnTo(
        uint256[] memory amounts,
        address[] memory tokens,
        address to
    ) external payable returns (uint256[] memory tokenAmount);

    function execute(address target, uint256 value, bytes memory data) external payable returns (bool success, bytes memory result);

    function withdraw(address token, uint256 amount) external returns (uint256 withdrawnAmount);

    function calcShareWeth(uint256 amount) external view returns (uint256 share);

    function calcShare(uint256 amount, address token) external view returns (uint256 share);

    function owner() external view returns (address);

}
