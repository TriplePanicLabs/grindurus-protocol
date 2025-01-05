// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {PriceOracleSelf} from "src/oracle/PriceOracleSelf.sol";
import {PriceOracleInverse} from "src/oracle/PriceOracleInverse.sol";
import {IPriceOracleRegistry} from "src/interfaces/IPriceOracleRegistry.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";

contract PriceOracleRegistryArbitrum is IPriceOracleRegistry {

    address private oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // chainlink WETH/USD oracle;

    address private wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @dev address of pools NFT. Used for fetching the owner
    IPoolsNFT public poolsNFT;

    /// @dev address of oracle, that return 1:1 price
    address public priceOracleSelf;

    /// @dev quote token => base token => oracle address
    mapping (address quoteToken => mapping(address baseToken => address)) internal oracles;

    constructor(address _poolsNFT) {
        if (_poolsNFT == address(0)) {
            poolsNFT = IPoolsNFT(msg.sender);
        } else {
            poolsNFT = IPoolsNFT(_poolsNFT);
        }
        PriceOracleSelf _priceOracleSelf = new PriceOracleSelf();
        priceOracleSelf = address(_priceOracleSelf);
        oracles[usdtArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
        oracles[usdcArbitrum][wethArbitrum] = oracleWethUsdArbitrum;
        PriceOracleInverse priceOracleInverse = new PriceOracleInverse(oracleWethUsdArbitrum);
        oracles[wethArbitrum][usdtArbitrum] = address(priceOracleInverse);
        oracles[wethArbitrum][usdcArbitrum] = address(priceOracleInverse);
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets oracle and deploy inverse oracle
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    function setOracle(address quoteToken, address baseToken, address oracle) public {
        _onlyOwner();
        oracles[quoteToken][baseToken] = oracle;
        PriceOracleInverse priceOracleInverse = new PriceOracleInverse(oracle);
        oracles[baseToken][quoteToken] = address(priceOracleInverse);
    }

    /// @notice returns oracle address of base token in terms of quote token
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    function getOracle(address quoteToken, address baseToken) public view override returns (address) {
        if (quoteToken == baseToken) {
            return priceOracleSelf;
        }
        return oracles[quoteToken][baseToken];
    }

    /// @notice return the owner
    function owner() public view returns (address) {
        try poolsNFT.owner() returns (address payable _owner) {
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

}