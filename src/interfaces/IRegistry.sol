// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    error NotOwner();
    error NotStrategiest();
    error QuoteTokenNotListed();
    error BaseTokenNotListed();
    error StrategyIdExist();
    error StrategyIdNotExist();
    error InvalidOracle();

    function strategyIdIndex(uint16 strategyId) external view returns (uint256);

    function strategyDescription(uint16 strategyId) external view returns (string memory);

    function quoteTokenIndex(address quoteToken) external view returns (uint256);

    function baseTokenIndex(address baseToken) external view returns (uint256);

    function oracles(address quoteToken, address baseToken) external view returns (address);

    function quoteTokenCoherence(address quoteToken) external view returns (uint256);

    function baseTokenCoherence(address baseToken) external view returns (uint256);

    function setOracle(address quoteToken, address baseToken, address oracle) external;

    function unsetOracle(address quoteToken, address baseToken, address oracle) external;

    function setStrategyPair(uint16 strategyId, address quoteToken, address baseToken, bool strategyPair) external;

    function addStrategyId(uint16 strategyId, string memory _strategyDescription) external;

    function modifyStrategyDescription(uint16 strategyId, string memory _strategyDescription) external;

    function removeStrategyId(uint16 strategyId) external;

    function getOracle(address quoteToken, address baseToken) external view returns (address);

    function isStrategyPair(uint256 strategyId, address quoteToken, address baseToken) external returns (bool);

    function owner() external view returns (address);

    function hasOracle(address quoteToken, address baseToken) external view returns (bool);

    function getStrategyIds() external view returns (uint256, uint16[] memory);

    function getStrategiesDescriptions(uint16[] memory _strategyIds) external view returns (string[] memory descriptions);

    function getQuoteTokens() external view returns (uint256, address[] memory);

    function getBaseTokens() external view returns (uint256, address[] memory);

    function getStrategyIds(uint256 fromId, uint256 toId) external view returns (uint256, uint16[] memory);

    function getQuoteTokens(uint256 fromId, uint256 toId) external view returns (uint256, address[] memory);

    function getBaseTokens(uint256 fromId, uint256 toId) external view returns (uint256, address[] memory);

}