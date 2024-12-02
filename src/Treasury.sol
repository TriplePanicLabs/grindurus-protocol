// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ITreasury} from "src/interfaces/ITreasury.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";

/// @title Treasury
/// @author riple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice stands as adapter to liquidity pool grETH/ETH
contract Treasury is ITreasury {
    /// @notice denominator. Used for calculating fee share
    /// @dev this value of denominator is 100%
    uint16 public constant DENOMINATOR = 100_00;

    /// @dev address of grindurus strategy positions NFT
    address public grindURUSPoolsNFT;

    /// @dev address of feeReceiver
    address payable public feeReceiver;

    /// @dev fee numerator
    uint16 public feeNumerator;

    uint256 public onGrindCounter;

    uint256 public onBuyRoyaltyCounter;

    constructor(address _grindurusPoolsNFT) {
        if (_grindurusPoolsNFT != address(0)) {
            grindURUSPoolsNFT = _grindurusPoolsNFT;
        } else {
            grindURUSPoolsNFT == msg.sender;
        }
        feeNumerator = DENOMINATOR; // fee 100%
        feeReceiver = payable(msg.sender);
    }

    /// @notice checks that msg.sender is grindurus pools NFT
    function _onlyPoolsNFT() private view {
        if (msg.sender != grindURUSPoolsNFT) {
            revert NotGrindURUSPoolsNFT();
        }
    }

    /// @notice check that msg.sender is grindURUS owner
    function _onlyOwner() private view {
        address owner;
        try IPoolsNFT(grindURUSPoolsNFT).owner() returns (
            address payable _owner
        ) {
            owner = _owner;
        } catch {
            owner = grindURUSPoolsNFT;
        }
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    /// @dev sets fee numerator for fee receiver
    /// @param _feeNumerator numerator of fee to `feeReceiver`
    function setFeeNumerator(uint16 _feeNumerator) external override {
        _onlyOwner();
        if (_feeNumerator > DENOMINATOR) {
            revert InvalidFeeNumerator();
        }
        feeNumerator = _feeNumerator;
    }

    /// @dev callable only by grindURUSPoolsNFT
    /// @param poolId id of pool on `grindURUSPoolsNFT`
    function onGrind(uint256 poolId) external override {
        _onlyPoolsNFT();
        poolId;
        onGrindCounter++;
    }

    function onBuyRoyalty(uint256 poolId) external override {
        _onlyPoolsNFT();
        poolId;
        onBuyRoyaltyCounter++;
    }

    function execute(
        address payable target,
        uint256 value,
        bytes calldata data
    ) external {
        _onlyOwner();
        (bool success, ) = target.call{value: value}(data);
        if (!success) {
            emit FailExecute();
        }
    }

    receive() external payable {
        // Treasury is able to hold ETH
    }
}
