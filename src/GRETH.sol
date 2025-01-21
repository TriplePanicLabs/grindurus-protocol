// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IGRETH, IToken} from "./interfaces/IGRETH.sol";
import {IPoolsNFT} from "./interfaces/IPoolsNFT.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GrindURUS Token grETH
/// @dev this ERC20 token is treasury of accumulated profits from stategies.
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice incentivization token for grinding the strategy
contract GRETH is IGRETH, ERC20 {
    using SafeERC20 for IToken;

    /// @dev address of grindurus strategy positions NFT
    IPoolsNFT public poolsNFT;

    /// @dev address of weth
    IToken public weth;

    /// @dev total grinded
    uint256 public totalGrinded;

    /// @dev account address => amount grETH minted
    mapping (address account => uint256) public totalMintedBy;

    constructor(address _poolsNFT, address _weth) ERC20("GrindURUS ETH", "grETH") {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT == IPoolsNFT(msg.sender);
        }
        weth = IToken(_weth);
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != address(poolsNFT)) {
            revert NotPoolsNFT();
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
        uint256[] memory amounts
    ) public returns (uint256 totalShares) {
        _onlyPoolsNFT();
        if (actors.length != amounts.length) {
            return 0;
        }
        uint256 len = actors.length;
        for (uint256 i; i < len; ) {
            if (amounts[i] > 0) {
                _mint(actors[i], amounts[i]);
                totalMintedBy[actors[i]] += amounts[i];
                totalGrinded += amounts[i];
                totalShares += amounts[i];
            }
            unchecked { ++i; }
        }
        emit Mint(actors, amounts, totalShares);
    }

    /// @notice burns grETH and get token
    /// @param amount amount of grETH
    /// @param token address of token to earn instead
    function burn(
        uint256 amount,
        address token
    ) public payable override returns (uint256 tokenAmount) {
        address payable burner = payable(msg.sender);
        uint256 balance;
        if (burner == owner()) {
            /// owner dont hold grETH, so it is internal mechanism
            balance = balanceOf(address(this));
        } else {
            balance = balanceOf(burner);
        }
        if (amount == 0 || amount > balance) {
            revert InvalidAmount();
        }
        tokenAmount = calcShare(amount, token);
        if (tokenAmount == 0) {
            revert ZeroTokenAmount();
        }
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount, token, tokenAmount);
        if (token == address(0)) {
            (bool success,) = burner.call{value: tokenAmount}("");
            if (!success) {
                revert FailTransferETH();
            }
        } else {
            IToken(token).safeTransfer(burner, tokenAmount);
        }
    }

    /// @notice batch burns grETH and get tokens
    /// @param amounts array of amounts of grETH
    /// @param tokens array of addresses of token to earn
    function batchBurn(
        uint256[] memory amounts,
        address[] memory tokens
    ) public payable override returns (uint256 tokenAmount) {
        uint256 len = amounts.length;
        if (len > 0 && len != tokens.length) {
            revert InvalidLength();
        }
        for (uint256 i; i < len; ) {
            tokenAmount += burn(amounts[i], tokens[i]);
            unchecked { ++i; }
        }
    }

    /// @notice calculates the calcShare of token
    /// @param amount grETH amount
    /// @param token address of token to calculate the calcShare
    function calcShare(
        uint256 amount,
        address token
    ) public view override returns (uint256 share) {
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
            share = totalLiquidity * amount / supply;
        }
    }

    /// @notice returns address of owner
    function owner() public view override returns (address) {
        try poolsNFT.owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice swap tokens to weth
    /// @param token address of token to be swapped from
    /// @param amountIn amount of token
    /// @param amountOut amount of weth
    /// @param target address of target contract (swap router)
    /// @param data swap data
    function swap(
        address token,
        uint256 amountIn,
        uint256 amountOut,
        address target,
        bytes calldata data
    ) public {
        _onlyOwner();

        uint256 tokenBalanceBefore = IToken(token).balanceOf(address(this));
        IToken(token).forceApprove(target, amountIn);
        uint256 targetTokenBalanceBefore = weth.balanceOf(address(this));
        
        (bool success, bytes memory result) = target.call(data);
        require(success, "swap fail");
        
        uint256 tokenBalanceAfter = IToken(token).balanceOf(address(this));
        uint256 targetTokenBalanceAfter = weth.balanceOf(address(this));

        require(tokenBalanceBefore - tokenBalanceAfter >= amountIn, "Insufficient amountIn");
        require(targetTokenBalanceAfter - targetTokenBalanceBefore >= amountOut, "Insufficient amountOut");
    }

    receive() external payable {}

}
