// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {IGRETH, IToken} from "./interfaces/IGRETH.sol";
import {IPoolsNFT} from "./interfaces/IPoolsNFT.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GrindURUS Token grETH
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice incentivization token for grinding the strategy
contract GRETH is IGRETH, ERC20 {
    using SafeERC20 for IToken;

    /// @dev address of grindurus strategy positions NFT
    address public poolsNFT;

    /// @dev total grinded
    uint256 public totalGrinded;

    /// @dev account address => amount grETH minted
    mapping (address account => uint256) public totalMintedBy;

    constructor(address _poolsNFT) ERC20("GrindURUS ETH", "grETH") {
        if (_poolsNFT != address(0)) {
            poolsNFT = _poolsNFT;
        } else {
            poolsNFT == msg.sender;
        }
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != poolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice mint GRETH to actors.
    /// @dev callable only by `poolsNFT`
    function mint(
        address[] memory actors,
        uint256[] memory shares
    ) public returns (uint256 totalShares) {
        _onlyPoolsNFT();
        if (actors.length != shares.length) {
            return 0;
        }
        uint256 len = actors.length;
        uint256 i = 0;
        for (; i < len; ) {
            if (shares[i] > 0) {
                _mint(actors[i], shares[i]);
                totalMintedBy[actors[i]] += shares[i];
                totalGrinded += shares[i];
                totalShares += shares[i];
            }
            unchecked { ++i; }
        }
    }

    /// @notice burns grETH and get token
    /// @param amount amount of grETH
    function burn(uint256 amount, address token) external payable {
        address payable burner = payable(msg.sender);
        uint256 balance;
        uint256 tokenAmount;
        if (burner == owner()) {
            balance = balanceOf(address(this));
        } else {
            balance = balanceOf(burner);
        }
        if (amount == 0 || amount > balance) {
            revert InvalidAmount();
        }
        tokenAmount = share(amount, token);
        _burn(msg.sender, amount);
        if (tokenAmount > 0) {
            if (token == address(0)) {
                (bool success,) = burner.call{value: tokenAmount}("");
            } else {
                IToken(token).safeTransfer(burner, tokenAmount);
            }
        }
    }

    /// @notice calculates the share of token
    /// @param token address of token to calculate the share
    /// @param amount grETH amount
    function share(uint256 amount, address token) public view returns (uint256) {
        uint256 totalLiquidity;
        if (token == address(0)) {
            totalLiquidity = address(this).balance;
        } else {
            totalLiquidity = IToken(token).balanceOf(address(this));
        }
        uint256 supply = totalSupply();
        if (amount > supply) {
            revert AmountExceededSupply();
        }
        if (supply > 0) {
            return totalLiquidity * amount / supply;
        } else {
            return 0;
        }
    }

    /// @notice returns address of owner
    function owner() public view returns (address) {
        try IPoolsNFT(poolsNFT).owner() returns (address payable owner) {
            return owner;
        } catch {
            return poolsNFT;
        }
    }

    receive() external payable {}

}
