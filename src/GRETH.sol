// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IGRETH, IToken} from "./interfaces/IGRETH.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
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
    IWETH9 public weth;

    /// @dev total grinded
    uint256 public totalGrinded;

    /// @dev account address => amount grETH minted
    mapping (address account => uint256) public totalMintedBy;

    /// @param _poolsNFT address of poolsNFT
    /// @param _weth address of WETH
    constructor(address _poolsNFT, address _weth) ERC20("GrindURUS ETH", "grETH") {
        if (_poolsNFT != address(0)) {
            poolsNFT = IPoolsNFT(_poolsNFT);
        } else {
            poolsNFT == IPoolsNFT(msg.sender);
        }
        weth = IWETH9(_weth);
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

    /// @notice mint GRETH based on ETH amount to `msg.sender`
    function mint() public payable override returns (uint256 mintedAmount) {
        mintedAmount = _mintTo(msg.sender);
    }

    /// @notice mint GRETH based on ETH amount to `receiver` 
    /// @param receiver address of account that receive grETH
    function mintTo(address receiver) public payable override returns (uint256 mintedAmount) {
        mintedAmount = _mintTo(receiver);
    }

    /// @notice mint GRETH
    /// @param receiver address of receiver
    function _mintTo(address receiver) internal returns (uint256 mintedAmount) {
        mintedAmount = msg.value;
        try weth.deposit{value: mintedAmount}() {
            address _owner = owner();
            if (receiver == _owner){
                _mint(address(this), mintedAmount);
            } else {
                _mint(receiver, mintedAmount);
            }
        } catch {
            mintedAmount = 0;
            revert FailMint();
        }
    }

    /// @notice mint GRETH to actors.
    /// @dev callable only by `poolsNFT`
    /// @param actors array of actors
    /// @param amounts array of amounts that should be minted to amounts
    function mint(
        address[] memory actors,
        uint256[] memory amounts
    ) public returns (uint256 totalShares) {
        _onlyPoolsNFT();
        if (actors.length != amounts.length) {
            return 0;
        }
        address _owner = owner();
        uint256 len = actors.length;
        for (uint256 i; i < len; ) {
            if (amounts[i] > 0) {
                if (actors[i] == _owner) {
                    _mint(address(this), amounts[i]);
                } else {
                    _mint(actors[i], amounts[i]);
                }
                totalMintedBy[actors[i]] += amounts[i];
                totalGrinded += amounts[i];
                totalShares += amounts[i];
            }
            unchecked { ++i; }
        }
        emit Mint(actors, amounts, totalShares);
    }

    /// @notice burns grETH and get weth
    /// @param amount amount of grETH
    function burn(uint256 amount) public override returns (uint256 tokenAmount) {
        tokenAmount = burn(amount, address(weth));
    }

    /// @notice burns grETH and get token `msg.sender`
    /// @param amount amount of grETH
    /// @param token address of token to earn instead
    function burn(
        uint256 amount,
        address token
    ) public payable override returns (uint256 tokenAmount) {
        tokenAmount = burnTo(amount, token, msg.sender);
    }

    /// @notice burns grETH and get token to `to`
    /// @param amount amount of grETH
    /// @param token address of token to earn instead
    /// @param to recipient of funds
    function burnTo(
        uint256 amount,
        address token,
        address to
    ) public payable override returns (uint256 tokenAmount) {
        address payable burner;
        if (msg.sender == owner()) {
            /// owner dont hold grETH. It is internal mechanism for sharing profit to owner
            burner = payable(address(this));
        } else {
            burner = payable(msg.sender);
        }
        uint256 balance = balanceOf(burner);
        amount = (amount == type(uint256).max) ? balance : amount;
        if (amount == 0 || amount > balance) {
            revert InvalidAmount();
        }
        tokenAmount = calcShare(amount, token);
        if (tokenAmount == 0) {
            revert ZeroTokenAmount();
        }
        _burn(burner, amount);
        emit Burn(burner, amount, token, tokenAmount);
        if (token == address(0)) {
            (bool success,) = payable(to).call{value: tokenAmount}("");
            if (!success) {
                revert FailTransferETH();
            }
        } else {
            IToken(token).safeTransfer(to, tokenAmount);
        }
    }

    /// @notice batch burns grETH on behalf of `msg.sender`
    /// @param amounts array of amounts of grETH
    /// @param tokens array of addresses of token to earn
    function batchBurn(
        uint256[] memory amounts,
        address[] memory tokens
    ) public payable override returns (uint256[] memory) {
        return batchBurnTo(amounts, tokens, msg.sender);
    }

    /// @notice batch burns grETH on behalf of `to`
    /// @param amounts array of amounts of grETH
    /// @param tokens array of addresses of token to earn
    function batchBurnTo(
        uint256[] memory amounts,
        address[] memory tokens,
        address to
    ) public payable override returns (uint256[] memory tokenAmount) {
        uint256 len = amounts.length;
        if (len > 0 && len != tokens.length) {
            revert InvalidLength();
        }
        tokenAmount = new uint256[](len);
        for (uint256 i; i < len; ) {
            tokenAmount[i] = burnTo(amounts[i], tokens[i], to);
            unchecked { ++i; }
        }
    }

    /// @notice withdraw token on owner determination. Forbid to withdraw WETH. 
    /// @dev practical usecase, that token withdrawn and transfered WETH to GRETH
    /// @param token address of token to pick
    /// @param amount amount of token to pick
    function withdraw(address token, uint256 amount) public override returns (uint256 withdrawnAmount) {
        _onlyOwner();
        if (token == address(weth)) {
            revert Forbid();
        }
        if (amount == type(uint256).max) {
            amount = (token == address(0)) 
                ? address(this).balance 
                : IToken(token).balanceOf(address(this));
        }
        if (token == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) {
                revert FailTransferETH();
            }
        } else {
            IToken(token).safeTransfer(msg.sender, amount);
        }
        withdrawnAmount = amount;
    }

    /// @notice calculates the calcShare of weth
    /// @param amount grETH amount
    function calcShareWeth(uint256 amount) public view override returns (uint256 share) {
        share = calcShare(amount, address(weth));
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

    /// @notice execute any transaction on target smart contract
    /// @dev callable only by owner
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    function execute(address target, uint256 value, bytes memory data) public payable virtual override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        try weth.deposit{value: msg.value}() {
            // successfully deposited
        } catch {
            // hold ETH on smart contract
        }
    }

}
