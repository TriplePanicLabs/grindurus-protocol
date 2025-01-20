// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {PriceOracleSelf} from "src/oracles/PriceOracleSelf.sol";
import {PriceOracleInverse} from "src/oracles/PriceOracleInverse.sol";

/// @title RegistryArbitrum
/// @dev stores array of strategy ids, strategy pairs, quote tokens, base tokens, and bounded oracles
contract Registry is IRegistry {

    /// @dev address of pools NFT. Used for fetching the owner
    IPoolsNFT public poolsNFT;

    /// @dev address of oracle, that return 1:1 price
    address public priceOracleSelf;

    /// @dev array of strategy ids
    uint16[] public strategyIds;

    /// @dev set of quote token
    address[] public quoteTokens;

    /// @dev set of base token
    address[] public baseTokens;

    /// @dev strategy id => index of strategy in array `strategyIds`
    mapping (uint16 strategyId => uint256) public strategyIdIndex;

    /// @dev strategy id => description of strategy
    mapping (uint16 strategyId => string) public strategyDescription;

    /// @dev quote token address => index of quote token in array `quoteTokens`
    mapping (address quoteToken => uint256) public quoteTokenIndex;

    /// @dev quote token address => index of quote token in array `baseTokens`
    mapping (address baseToken => uint256) public baseTokenIndex;

    /// @dev quote token address => base token address => oracle address
    mapping (address quoteToken => mapping(address baseToken => address)) public oracles;

    /** c === coherence = sum of raws minus one (exclude diagonal element)
           b0 b1 b2 b3   
         q0 1  1  1  0  c(q0) = 3 - 1 = 2
    A0 = q1 1  1  0  0  c(q1) = 2 - 1 = 1
         q2 1  0  1  1  c(q2) = 3 - 1 = 2
         q3 0  0  1  1  c(q3) = 2 - 1 = 1

                        c(b0) = 3 - 1 = 2
                        c(b1) = 2 - 1 = 1
                        c(b2) = 3 - 1 = 2
                        c(b3) = 2 - 1 = 1

    Add oracle to q0+b3

           b0 b1 b2 b3
         q0 1  1  1  1  c(q0) = 4 - 1 = 3
    A1 = q1 1  1  0  0  c(q1) = 2 - 1 = 1
         q2 1  0  1  1  c(q2) = 3 - 1 = 2
         q3 1  0  1  1  c(q3) = 3 - 1 = 2
        
                        c(b0) = 4 - 1 = 3
                        c(b1) = 2 - 1 = 1
                        c(b2) = 3 - 1 = 2
                        c(b3) = 3 - 1 = 2

     */

    /// @dev quote token => coherence of quote token
    mapping (address quoteToken => uint256) public quoteTokenCoherence;

    /// @dev base token address => coherence of base token
    mapping (address baseToken => uint256) public baseTokenCoherence;

    /// @dev id of strategy => address of token => allowed token for strategy
    mapping (uint256 strategyId => mapping (address quoteToken => mapping(address baseToken => bool))) internal _strategyPairs;

    constructor(address _poolsNFT) {
        if (_poolsNFT == address(0)) {
            poolsNFT = IPoolsNFT(msg.sender);
        } else {
            poolsNFT = IPoolsNFT(_poolsNFT);
        }
        PriceOracleSelf _priceOracleSelf = new PriceOracleSelf();
        priceOracleSelf = address(_priceOracleSelf);

    }

      /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    function _onlyStrategiest() internal view {
        if (address(poolsNFT) == address(0)) {
            if (msg.sender != owner()) {
                revert NotOwner();
            }
        } else {
            if(!poolsNFT.isStrategiest(msg.sender)) {
                revert NotStrategiest();
            }
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

    /// @notice set strategy pair
    /// @param strategyId id of strategy
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    /// @param _isStrategyPair true - strategy pair, false - not strategy pair
    function setStrategyPair(uint16 strategyId, address quoteToken, address baseToken, bool _isStrategyPair) public override {
        _onlyStrategiest();
        if (quoteTokenCoherence[quoteToken] == 0) {
            revert QuoteTokenNotListed();
        }
        if (baseTokenCoherence[baseToken] == 0) {
            revert BaseTokenNotListed();
        }
        _strategyPairs[strategyId][quoteToken][baseToken] = _isStrategyPair;
    }

    /// @notice add strategy id to `strategyIds` array
    /// @param strategyId id of strategy
    /// @param _strategyDescription description of strategy
    function addStrategyId(uint16 strategyId, string memory _strategyDescription) public {
        _onlyStrategiest();
        if (strategyIds[strategyIdIndex[strategyId]] == strategyId) {
            revert StrategyIdExist();
        }
        strategyIdIndex[strategyId] = strategyIds.length;
        strategyIds.push(strategyId);
        strategyDescription[strategyId] = _strategyDescription;
    }

    /// @notice modify strategy description
    /// @param strategyId id of strategy
    /// @param _strategyDescription description of strategy
    function modifyStrategyDescription(uint16 strategyId, string memory _strategyDescription) public {
        _onlyStrategiest();
        if (strategyIds[strategyIdIndex[strategyId]] != strategyId) {
            revert StrategyIdNotExist();
        }
        strategyDescription[strategyId] = _strategyDescription;
    }

    /// @notice remove strategy id from `strategyIds`
    /// @param strategyId id of strategy
    function removeStrategyId(uint16 strategyId) public override {
        _onlyStrategiest();
        uint256 _strategyIdIndex = strategyIdIndex[strategyId];
        if (strategyIds[_strategyIdIndex] != strategyId) {
            revert StrategyIdNotExist();
        }
        uint256 lastStrategyIdIndex = strategyIds.length - 1;
        if (_strategyIdIndex != lastStrategyIdIndex) {
            strategyIds[_strategyIdIndex] = strategyIds[lastStrategyIdIndex];
        }
        strategyIds.pop();
        delete strategyDescription[strategyId];
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

    /// @notice returns if it is strategy pair
    /// @param strategyId id of strategy
    /// @param quoteToken address of quote token
    /// @param baseToken address of base token
    function isStrategyPair(uint256 strategyId, address quoteToken, address baseToken) public view override returns (bool) {
        if (strategyId == 0 && quoteTokenCoherence[quoteToken] > 0 && baseTokenCoherence[baseToken] > 0) {
            return true;
        }
        return _strategyPairs[strategyId][quoteToken][baseToken];
    }

    /// @notice return the owner
    function owner() public view override returns (address) {
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

    /// @notice returns `strategyIds` array
    function getStrategyIds() public view override returns (uint256, uint16[] memory) {
        return (strategyIds.length, strategyIds);
    }

    /// @notice returns `quoteTokens` array
    function getQuoteTokens() public view override returns (uint256, address[] memory) {
        return (quoteTokens.length, quoteTokens);
    }

    /// @notice returns `baseTokens` array
    function getBaseTokens() public view override returns (uint256, address[] memory) {
        return (baseTokens.length, baseTokens);
    }

    /// @notice returns `strategyIds` array
    /// @param fromId index from in `quoteTokens` array
    /// @param toId index to in `quoteTokens` array
    function getStrategyIds(uint256 fromId, uint256 toId) public view override returns (uint256, uint16[] memory) {
        require(fromId <= toId);
        uint256 len = toId - fromId + 1;
        uint16[] memory _strategyIds = new uint16[](len);
        for (uint256 i; i < len;) {
            _strategyIds[i] = strategyIds[fromId + i];
            unchecked { ++i; }
        }
        return (len, _strategyIds);
    }

    /// @notice returns length and slice array `quoteTokens` from index `from` to index `to`
    /// @param fromId index from in `quoteTokens` array
    /// @param toId index to in `quoteTokens` array
    function getQuoteTokens(uint256 fromId, uint256 toId) public view override returns (uint256, address[] memory) {
        require(fromId <= toId);
        uint256 len = toId - fromId + 1;
        address[] memory _quoteTokens = new address[](len);
        for (uint256 i; i < len;) {
            _quoteTokens[i] = quoteTokens[fromId + i];
            unchecked { ++i; }
        }
        return (len, _quoteTokens);
    }

    /// @notice returns length and slice array `baseTokens` from index `from` to index `to`
    /// @param fromId index from in `baseTokens` array
    /// @param toId index to in `baseTokens` array
    function getBaseTokens(uint256 fromId, uint256 toId) public view override returns (uint256, address[] memory) {
        require(fromId <= toId);
        uint256 len = toId - fromId + 1;
        address[] memory _baseTokens = new address[](len);
        for (uint256 i; i < len;) {
            _baseTokens[i] = baseTokens[fromId + i];
            unchecked { ++i; }
        }
        return (len, _baseTokens);
    }

}