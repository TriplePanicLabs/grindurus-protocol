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

    /// @dev total grinded
    uint256 public totalGrinded;

    /// @dev account address => amount grETH minted
    mapping (address account => uint256) public totalMintedBy;

    constructor(address _poolsNFT) ERC20("GrindURUS ETH", "grETH") {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT == IPoolsNFT(msg.sender);
        }
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
        tokenAmount = share(amount, token);
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

    /// @notice calculates the share of token
    /// @param amount grETH amount
    /// @param token address of token to calculate the share
    function share(
        uint256 amount,
        address token
    ) public view override returns (uint256 _share) {
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
            _share = totalLiquidity * amount / supply;
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

    /// @notice swap tokens
    /// @param fromToken address of token to be swapped from
    /// @param toToken address of token to swapped to
    /// @param fromTokenAmount amount of fromToken
    /// @param toTokenAmount amount of toToken
    /// @param target address of target contract (swap router)
    /// @param value amount of ETH
    /// @param data swap data
    function swap(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 toTokenAmount,
        address target,
        uint256 value,
        bytes calldata data
    ) public {
        _onlyOwner();
        require(fromToken != address(this), "fromToken==grETH");
        require(fromToken != toToken, "fromToken==toToken");
        uint256 fromTokenBalanceBefore;
        if (fromToken == address(0)) {
            fromTokenBalanceBefore = address(this).balance;
        } else {
            fromTokenBalanceBefore = IToken(fromToken).balanceOf(address(this));
            IToken(fromToken).forceApprove(target, fromTokenAmount);
        }
        uint256 toTokenBalanceBefore;
        if (toToken == address(0)) {
            toTokenBalanceBefore = address(this).balance;
        } else {
            toTokenBalanceBefore = IToken(toToken).balanceOf(address(this));
        }
        
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "swap fail");
        
        uint256 fromTokenBalanceAfter;
        if (fromToken == address(0)) {
            fromTokenBalanceAfter = address(this).balance;
        } else {
            fromTokenBalanceAfter = IToken(fromToken).balanceOf(address(this));
        }
        uint256 toTokenBalanceAfter;
        if (toToken == address(0)) {
            toTokenBalanceAfter = address(this).balance;
        } else {
            toTokenBalanceAfter = IToken(toToken).balanceOf(address(this));
        }

        require(fromTokenBalanceBefore - fromTokenBalanceAfter >= fromTokenAmount, "Insufficient fromToken spent");
        require(toTokenBalanceAfter - toTokenBalanceBefore >= toTokenAmount, "Insufficient toToken received");
    }

    receive() external payable {}

}
