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

    /// @dev set of quote token
    address[] public quoteTokens;

    /// @dev set of base token
    address[] public baseTokens;

    /// @dev array of strategy infos
    StrategyInfo[] public strategyInfos;

    /// @dev array of endpoint ids of GRAI
    GRAIInfo[] public graiInfos;

    /// @dev strategy id => index in `strategyInfos` array
    mapping (uint16 strategyId => uint256) public strategyIdIndex;

    /// @dev endpoint id => index in `graiInfos` array
    mapping (uint32 endpointId => uint256) public graiIdIndex;

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
        priceOracleSelf = address(new PriceOracleSelf());
        strategyInfos.push(StrategyInfo({
            strategyId: 0,
            factory: address(0),
            description: ""
        }));
        graiInfos.push(GRAIInfo({
            endpointId: 0,
            grai: address(0),
            description: ""
        }));
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() internal view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets poolsNFT
    /// @param _poolsNFT address of poolsNFT
    function setPoolsNFT(address _poolsNFT) public {
        _onlyOwner();
        poolsNFT = IPoolsNFT(_poolsNFT);
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
        _onlyOwner();
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
    /// @param factory address of factory
    /// @param description description of strategy
    function addStrategyInfo(uint16 strategyId, address factory, string memory description) public override {
        _onlyOwner();
        if (strategyInfos[strategyIdIndex[strategyId]].strategyId == strategyId) {
            revert StrategyIdExist();
        }
        strategyIdIndex[strategyId] = strategyInfos.length;
        strategyInfos.push(StrategyInfo({
            strategyId: strategyId, 
            factory: factory,
            description: description
        }));
    }

    /// @notice modify strategy description
    /// @param strategyId id of strategy
    /// @param factory address of factory
    /// @param description description of strategy
    function altStrategyInfo(uint16 strategyId, address factory, string memory description) public override{
        _onlyOwner();

        uint256 _strategyIdIndex = strategyIdIndex[strategyId];
        if (strategyInfos[_strategyIdIndex].strategyId != strategyId) {
            revert NotMatchingStrategyId();
        }
        strategyInfos[_strategyIdIndex].factory = factory;
        strategyInfos[_strategyIdIndex].description = description;
    }

    /// @notice remove strategy id from `strategyIds`
    /// @param strategyId id of strategy
    function removeStrategyInfo(uint16 strategyId) public override {
        _onlyOwner();
        uint256 _strategyIdIndex = strategyIdIndex[strategyId];
        uint256 lastStrategyIdIndex = strategyInfos.length - 1;
        if (_strategyIdIndex != lastStrategyIdIndex) {
            strategyInfos[_strategyIdIndex] = strategyInfos[lastStrategyIdIndex];
        }
        strategyIdIndex[strategyId] = 0;
        strategyInfos.pop();
    }

    /// @notice add strategy id to `strategyIds` array
    /// @param endpointId id of layer zero endpoint
    /// @param grai address of GRAI
    /// @param description description of strategy
    function addGRAIInfo(uint32 endpointId, address grai, string memory description) public override {
        _onlyOwner();
        if (graiInfos[graiIdIndex[endpointId]].endpointId == endpointId) {
            revert EndpointIdExist();
        }
        graiIdIndex[endpointId] = graiInfos.length;
        graiInfos.push(GRAIInfo({
            endpointId: endpointId,
            grai: grai,
            description: description
        }));
    }

    /// @notice modify strategy description
    /// @param endpointId id of strategy
    /// @param grai address of GRAI
    /// @param description description of strategy
    function altGRAIInfo(uint32 endpointId, address grai, string memory description) public override {
        _onlyOwner();
        uint256 _graiIdIndex = graiIdIndex[endpointId];
        if (graiInfos[_graiIdIndex].endpointId != endpointId) {
            revert NotMatchingEndpointId();
        }
        graiInfos[_graiIdIndex].grai = grai;
        graiInfos[_graiIdIndex].description = description;
    }

    /// @notice remove strategy id from `strategyIds`
    /// @param endpointId id of layerZero endpoint
    function removeGRAIInfo(uint32 endpointId) public override {
        _onlyOwner();
        uint256 _graiIdIndex = graiIdIndex[endpointId];
        uint256 lastGraiIdIndex = graiInfos.length - 1;
        if (_graiIdIndex != lastGraiIdIndex) {
            graiInfos[_graiIdIndex] = graiInfos[lastGraiIdIndex];
        }
        graiIdIndex[endpointId] = 0;
        graiInfos.pop();
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

    /// @notice returns `quoteTokens` array
    function getQuoteTokens() public view override returns (address[] memory){
        return quoteTokens;
    }

    /// @notice returns `baseTokens` array
    function getBaseTokens() public view override returns (address[] memory) {
        return baseTokens;
    }

    /// @notice returns `strategyInfos` array
    function getStrategyInfos() public view override returns (StrategyInfo[] memory) {
        return strategyInfos;
    }

    /// @notice returns `GRAIInfos` array
    function getGRAIInfos() public view override returns (GRAIInfo[] memory) {
        return graiInfos;
    }

    /// @notice returns `strategyInfos` array
    function getStrategyInfosBy(uint256[] memory strategyInfosIds) public view override returns (StrategyInfo[] memory _strategyInfos) {
        uint256 len = strategyInfosIds.length;
        _strategyInfos = new StrategyInfo[](len);
        for (uint256 i; i < len;) {
            _strategyInfos[i] = strategyInfos[strategyInfosIds[i]];
            unchecked { ++i; }
        }
    }

    /// @notice returns `graiInfos` array
    function getGRAIInfosBy(uint256[] memory graiInfosIds) public view override returns (GRAIInfo[] memory _graiInfos) {
        uint256 len = graiInfosIds.length;
        _graiInfos = new GRAIInfo[](len);
        for (uint256 i; i < len;) {
            _graiInfos[i] = graiInfos[graiInfosIds[i]];
            unchecked { ++i; }
        }
    }

    /// @notice returns length and slice array `quoteTokens` from index `from` to index `to`
    /// @param quoteTokenIds array of index`es of `quoteTokens` 
    function getQuoteTokensBy(uint256[] memory quoteTokenIds) public view override returns (address[] memory _quoteTokens) {
        uint256 len = quoteTokenIds.length;
        _quoteTokens = new address[](len);
        for (uint256 i; i < len;) {
            _quoteTokens[i] = quoteTokens[quoteTokenIds[i]];
            unchecked { ++i; }
        }
    }

    /// @notice returns length and slice array `baseTokens` from index `from` to index `to`
    /// @param baseTokenIds array of index`es of `baseTokens` 
    function getBaseTokensBy(uint256[] memory baseTokenIds) public view override returns (address[] memory _baseTokens) {
        uint256 len = baseTokenIds.length;
        _baseTokens = new address[](len);
        for (uint256 i; i < len;) {
            _baseTokens[i] = baseTokens[baseTokenIds[i]];
            unchecked { ++i; }
        }
    }

}