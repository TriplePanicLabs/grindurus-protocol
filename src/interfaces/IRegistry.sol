// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    error NotOwner();
    error InvalidOracle();

    function setOracle(address quoteToken, address baseToken, address oracle) external;

    function unsetOracle(address quoteToken, address baseToken, address oracle) external;

    function getOracle(address quoteToken, address baseToken) external view returns (address);

    function hasOracle(address quoteToken, address baseToken) external view returns (bool);

    function getQuoteTokens() external view returns (uint256, address[] memory);

    function getBaseTokens() external view returns (uint256, address[] memory);

    function getQuoteTokens(uint256 from, uint256 to) external view returns (uint256, address[] memory);

    function getBaseTokens(uint256 from, uint256 to) external view returns (uint256, address[] memory);

}