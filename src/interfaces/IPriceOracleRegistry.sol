// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracleRegistry {
    error NotOwner();

    function setOracle(address quoteToken, address baseToken, address oracle) external;

    function getOracle(address quoteToken, address baseToken) external view returns (address);

}