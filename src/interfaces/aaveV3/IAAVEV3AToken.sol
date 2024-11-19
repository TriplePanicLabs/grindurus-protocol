// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAToken
/// @author Aave
/// @notice Defines the basic interface for an Aave aToken.
interface IAAVEV3AToken { 

    function balanceOf(address) external view returns (uint256);

}