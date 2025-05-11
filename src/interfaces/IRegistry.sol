// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    error NotOwner();
    error QuoteTokenNotListed();
    error BaseTokenNotListed();
    error StrategyIdExist();
    error EndpointIdExist();
    error NotMatchingStrategyId();
    error NotMatchingEndpointId();
    error GRAIExist();
    error StrategyIdNotExist();
    error InvalidOracle();

    event SetStrategyInfo(uint16 strategyId, address factory, string description);
    event SetGRAIInfo(uint32 endpointId, address grai, string description);

    struct StrategyInfo {
        uint16 strategyId;
        address factory;
        string description;
    }

    struct GRAIInfo {
        uint32 endpointId;
        address grai;
        string description;
    }

    function quoteTokenIndex(address quoteToken) external view returns (uint256);

    function baseTokenIndex(address baseToken) external view returns (uint256);

    function oracles(address quoteToken, address baseToken) external view returns (address);

    function quoteTokenCoherence(address quoteToken) external view returns (uint256);

    function baseTokenCoherence(address baseToken) external view returns (uint256);

    function setOracle(address quoteToken, address baseToken, address oracle) external;

    function unsetOracle(address quoteToken, address baseToken, address oracle) external;

    function setStrategyInfo(uint16 strategyId, address factory, string memory description) external;

    function setGRAIInfo(uint32 endpointId, address grai, string memory description) external;

    function getOracle(address quoteToken, address baseToken) external view returns (address);

    function owner() external view returns (address);

    function hasOracle(address quoteToken, address baseToken) external view returns (bool);

    function getQuoteTokens() external view returns (address[] memory);

    function getBaseTokens() external view returns (address[] memory);

    function getStrategyInfosBy(uint16[] memory strategyIds) external view returns (StrategyInfo[] memory);

    function getGRAIInfosBy(uint32[] memory graiInfosIds) external view returns (GRAIInfo[] memory _graiInfos);

    function getQuoteTokensBy(uint256[] memory quoteTokensIds) external view returns (address[] memory);

    function getBaseTokensBy(uint256[] memory baseTokensIds) external view returns (address[] memory);

}