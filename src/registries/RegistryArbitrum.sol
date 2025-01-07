// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {PriceOracleSelf} from "src/oracle/PriceOracleSelf.sol";
import {PriceOracleInverse} from "src/oracle/PriceOracleInverse.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";

contract RegistryArbitrum is IRegistry {

    address private oracleWethUsdArbitrum = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // chainlink WETH/USD oracle;

    address private wethArbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address private usdtArbitrum = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private usdcArbitrum = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @dev address of pools NFT. Used for fetching the owner
    IPoolsNFT public poolsNFT;

    /// @dev address of oracle, that return 1:1 price
    address public priceOracleSelf;

    /// @dev set of quote token
    address[] public quoteTokens;

    /// @dev set of base token
    address[] public baseTokens;

    /// @dev quote token address => base token address => oracle address
    mapping (address quoteToken => mapping(address baseToken => address)) internal oracles;

    /// @dev quote token address => index of quote token in array `quoteTokens`
    mapping (address quoteToken => uint256) public quoteTokenIndex;

    /// @dev quote token address => index of quote token in array `baseTokens`
    mapping (address baseToken => uint256) public baseTokenIndex;

    /// @dev quote token => coherence of quote token
    mapping (address quoteToken => uint256) public quoteTokenCoherence;

    /// @dev base token address => coherence of base token
    mapping (address baseToken => uint256) public baseTokenCoherence;

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
        
        quoteTokens.push(usdtArbitrum);
        quoteTokens.push(usdcArbitrum);
        quoteTokens.push(wethArbitrum);
        
        baseTokens.push(wethArbitrum);
        baseTokens.push(usdtArbitrum);
        baseTokens.push(usdcArbitrum);
        
        quoteTokenIndex[usdtArbitrum] = 0;
        quoteTokenIndex[usdcArbitrum] = 1;
        quoteTokenIndex[wethArbitrum] = 2;

        baseTokenIndex[wethArbitrum] = 0;
        baseTokenIndex[usdtArbitrum] = 1;
        baseTokenIndex[usdcArbitrum] = 2;

        quoteTokenCoherence[usdtArbitrum]++;
        quoteTokenCoherence[usdcArbitrum]++;
        quoteTokenCoherence[wethArbitrum]++;

        baseTokenCoherence[wethArbitrum]++;
        baseTokenCoherence[usdtArbitrum]++;
        baseTokenCoherence[usdcArbitrum]++;

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
        if (quoteTokenCoherence[quoteToken] == 0) {
            quoteTokenIndex[quoteToken] = quoteTokens.length;
            quoteTokens.push(quoteToken);
        }
        if (baseTokenCoherence[baseToken] == 0) {
            baseTokenIndex[baseToken] = baseTokens.length;
            baseTokens.push(baseToken);
        }
        quoteTokenCoherence[quoteToken]++;
        quoteTokenCoherence[baseToken]++;
        baseTokenCoherence[baseToken]++;
        baseTokenCoherence[quoteToken]++;
    }

    /// @notice unsets oracles
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    function unsetOracle(address quoteToken, address baseToken, address oracle) public override {
        _onlyOwner();
        if (oracles[quoteToken][baseToken] != oracle || oracle == address(0)) {
            revert InvalidOracle();
        }
        delete oracles[quoteToken][baseToken];
        quoteTokenCoherence[quoteToken]--;
        if (quoteTokenCoherence[quoteToken] == 0) {
            uint256 _quoteTokenIndex = quoteTokenIndex[quoteToken];
            uint256 lastQuoteTokenIndex = quoteTokens.length > 0 ? quoteTokens.length - 1 : 0;
            if (_quoteTokenIndex != lastQuoteTokenIndex) {
                quoteTokens[_quoteTokenIndex] = quoteTokens[lastQuoteTokenIndex];
            }
            quoteTokens.pop();
        }
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

    /// @notice return if `quoteToken` and `baseToken` has oracle
    /// @param quoteToken address of `quoteToken`
    /// @param baseToken address of `baseToken`
    function hasOracle(address quoteToken, address baseToken) public view override returns (bool) {
        return oracles[quoteToken][baseToken] != address(0);
    }

    /// @notice returns `quoteTokens` array
    function getQuoteTokens() public view override returns (uint256, address[] memory) {
        return (quoteTokens.length, quoteTokens);
    }

    /// @notice returns `baseTokens` array
    function getBaseTokens() public view override returns (uint256, address[] memory) {
        return (baseTokens.length, baseTokens);
    }

    /// @notice returns length and slice array `quoteTokens` from index `from` to index `to`
    /// @param from index from in `quoteTokens` array
    /// @param to index to in `quoteTokens` array
    function getQuoteTokens(uint256 from, uint256 to) public view override returns (uint256, address[] memory) {
        require(from <= to, "from>to");
        uint256 len = to - from + 1;
        address[] memory _quoteTokens = new address[](len);
        for (uint256 i; i < len;) {
            _quoteTokens[i] = quoteTokens[from + i];
            unchecked { ++i; }
        }
        return (len, _quoteTokens);
    }
     
    /// @notice returns length and slice array `baseTokens` from index `from` to index `to`
    /// @param from index from in `baseTokens` array
    /// @param to index to in `baseTokens` array
    function getBaseTokens(uint256 from, uint256 to) public view override returns (uint256, address[] memory) {
        require(from <= to, "from>to");
        uint256 len = to - from + 1;
        address[] memory _baseTokens = new address[](len);
        for (uint256 i; i < len;) {
            _baseTokens[i] = baseTokens[from + i];
            unchecked { ++i; }
        }
        return (len, _baseTokens);
    }
}