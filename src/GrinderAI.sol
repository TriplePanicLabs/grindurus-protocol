// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IStrategy, IURUS} from "src/interfaces/IStrategy.sol";
import {Ownable2Step, Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGrinderAI} from "src/interfaces/IGrinderAI.sol";


/// @title GrinderAI
/// @notice provide transpanet mechanism for effective interaction with GrindURUS protocol via AI agent
contract GrinderAI is IGrinderAI {
    using SafeERC20 for IToken;

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

    /// @dev address of account => is agent
    mapping (address account => bool) public isAgent;

    /// @param _poolsNFT address of poolsNFT
    constructor (address _poolsNFT)  {
        poolsNFT = IPoolsNFT(_poolsNFT);
        isAgent[owner()] = true;
    }

    /// @notice return owner of grinderAI
    function owner() public view returns (address) {
        try poolsNFT.owner() returns(address payable _owner){
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice checks that msg.sender is agent
    function _onlyAgent() private view {
        if (!isAgent[msg.sender]) {
            revert NotAgent();
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice sets 
    /// @param _agent address of agent
    /// @param _isAgent true - agent, false - not agent
    function setAgent(address _agent, bool _isAgent) public {
        _onlyOwner();
        isAgent[_agent] = _isAgent;
    }

    /// @notice AI deposit
    /// @param strategyId id of strategy
    /// @param baseToken address of base token
    /// @param quoteToken address of quote token
    /// @param quoteTokenAmounts array of quote token amounts
    function mint(
        uint16 strategyId,
        address quoteToken,
        address baseToken,
        uint256[] memory quoteTokenAmounts
    ) public returns (uint256[] memory poolIds) {
        poolIds = mintTo(
            msg.sender,
            strategyId,
            quoteToken,
            baseToken,
            quoteTokenAmounts
        );
    }

    /// @notice AI deposit
    /// @param strategyId id of strategy
    /// @param baseToken address of base token
    /// @param quoteToken address of quote token
    /// @param quoteTokenAmounts array of quote token amounts
    function mintTo(
        address receiver,   
        uint16 strategyId,
        address baseToken,
        address quoteToken,
        uint256[] memory quoteTokenAmounts
    ) public returns (uint256[] memory poolIds) {
        uint256 len = quoteTokenAmounts.length;
        poolIds = new uint256[](len);
        for (uint256 i; i < len;) {
            poolIds[i] = poolsNFT.mintTo(
                receiver,
                strategyId,
                baseToken,
                quoteToken,
                quoteTokenAmounts[i]
            );
            unchecked { ++i; }
        }
    }

    /// @notice grind 
    /// @param poolId id of pool
    function grind(uint256 poolId) public override returns (bool) {
        address grinder = owner();
        try poolsNFT.grindTo(poolId, grinder) returns (bool isGrinded) {
            return isGrinded;
        } catch {
            return false;
        }
    }

    /// @notice AI grind
    /// @dev can be called by anyone
    /// @param poolIds array of pool ids
    function batchGrind(uint256[] memory poolIds) public override {
        uint256 len = poolIds.length;
        address grinder = owner();
        for (uint256 i = 0; i < len; ) {
            try poolsNFT.grindTo(poolIds[i], grinder) returns (bool isGrinded) {
                isGrinded;
            } catch {

            }
            unchecked { ++i; }
        }
    }

    /// @notice batch of grindOps
    /// @param poolIds array of pool ids
    /// @param ops array of ops
    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) public override {
        if (poolIds.length != ops.length) {
            revert InvalidLength();
        }
        address grinder = owner();
        uint256 len = poolIds.length;
        uint256 i;
        for (i = 0; i < len;) {
            try poolsNFT.grindOpTo(poolIds[i], ops[i], grinder) returns (bool isGrinded) {
                isGrinded;
            } catch {

            }
            unchecked { ++i; }
        }
    }

    /// @notice sets whole config
    /// @param poolId id of pool on poolsNFT
    /// @param config structure of config params
    function setConfig(uint256 poolId, IURUS.Config memory config) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setConfig(config);
    }

    /// @notice sets long number max
    /// @param poolId id of pool on poolsNFT
    /// @param longNumberMax param longNumberMax on IURUS.Config
    function setLongNumberMax(uint256 poolId, uint8 longNumberMax) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setLongNumberMax(longNumberMax);
    }

    /// @notice sets hedge number max
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param hedgeNumberMax param hedgeNumberMax on IURUS.Config
    function setHedgeNumberMax(uint256 poolId, uint8 hedgeNumberMax) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setHedgeNumberMax(hedgeNumberMax);
    }

    /// @notice sets extra coef
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param extraCoef param extraCoef on IURUS.Config
    function setExtraCoef(uint256 poolId, uint256 extraCoef) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setExtraCoef(extraCoef);
    }

    /// @notice sets price volatility percent
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param priceVolatilityPercent param priceVolatilityPercent on IURUS.Config
    function setPriceVolatilityPercent(uint256 poolId, uint256 priceVolatilityPercent) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setPriceVolatilityPercent(priceVolatilityPercent);
    }

    /// @notice sets return percent
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param op operation on IURUS.Op enumeration
    /// @param returnPercent param returnPercent on IURUS.Config 
    function setOpReturnPercent(uint256 poolId, uint8 op, uint256 returnPercent) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setOpReturnPercent(op, returnPercent);
    }

    /// @notice sets fee coef
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param op operation on IURUS.Op enumeration
    /// @param feeCoef param feeCoef on IURUS.FeeConfig 
    function setOpFeeCoef(uint256 poolId, uint8 op, uint256 feeCoef) public override {
        _onlyAgent();
        IStrategy(poolsNFT.pools(poolId)).setOpFeeCoef(op, feeCoef);
    }

    /// @notice execute any transaction
    /// @param target address of target
    /// @param value amount of ETH
    /// @param data calldata to target
    function execute(address target, uint256 value, bytes calldata data) public override {
        _onlyOwner();
        (bool success, ) = target.call{value: value}(data);
        success;
    }

    /// @notice return version of GrinderAI
    function version() public pure returns (uint256) {
        return 0;
    }

    receive() external payable {
        if (msg.value > 0) {
            bool success;
            (success, ) = address(owner()).call{value: msg.value}("");
        }
    }

}