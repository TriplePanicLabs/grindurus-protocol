// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IToken } from "src/interfaces/IToken.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IAgent } from "src/interfaces/IAgent.sol";
import { IStrategy, IURUS } from "src/interfaces/IStrategy.sol";
import { Ownable2Step, Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";
import { IGrinderAI, IWETH9 } from "src/interfaces/IGrinderAI.sol";
import { IIntentsNFT } from "src/interfaces/IIntentsNFT.sol";

/// @title GrinderAI
/// @notice provide transpanet mechanism for effective interaction with GrindURUS protocol via AI agent
contract GrinderAI is IGrinderAI {
    using SafeERC20 for IToken;

    /// @notice denominator. Used for calculating royalties
    /// @dev this value of denominator is 100% 
    uint16 public constant DENOMINATOR = 100_00;

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

    /// @dev address of intentNFT
    IIntentsNFT public intentsNFT;

    /// @dev address of grAI
    IGRAI public grAI;

    /// @dev address of weth
    IWETH9 public weth;

    /// @dev address of grinder
    address payable public grinder;

    /// @dev grinder share of value
    uint16 public grinderShareNumerator;

    /// @dev grinder share of value
    uint16 public liquidityShareNumerator;

    /// @dev address of account => is agent
    mapping (address account => bool) public isDelegate;

    /// @dev address of account => amount of minted grAI
    mapping (address account => uint256) public mintedGrinds;

    /// @notice initialize function
    function init(address _poolsNFT, address _intentsNFT, address _grAI, address _weth) public override {
        require(
            address(poolsNFT) == address(0) && 
            address(intentsNFT) == address(0) && 
            address(grAI) == address(0) &&
            address(weth) == address(0)
        );
        poolsNFT = IPoolsNFT(_poolsNFT);
        intentsNFT = IIntentsNFT(_intentsNFT);
        grAI = IGRAI(_grAI);
        weth = IWETH9(_weth);
        grinder = payable(owner());
        grinderShareNumerator = 50_00;
        liquidityShareNumerator = 50_00;
        require(grinderShareNumerator + liquidityShareNumerator == DENOMINATOR, "Invalid shares");
        isDelegate[msg.sender] = true;
    }

    /// @notice return owner of grinderAI
    function owner() public view returns (address) {
        try poolsNFT.owner() returns(address payable _owner){
            return _owner;
        } catch {
            return address(poolsNFT);
        }
    }

    /// @notice checks that msg.sender is owner
    function _onlyOwner() private view {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
    }

    /// @notice checks that msg.sender is agent
    function _onlyDelegate() private view {
        if (!isDelegate[msg.sender]) {
            revert NotDelegate();
        }
    }

    /// @notice sets delegate
    /// @param _delegate address of delegate
    /// @param _isDelegate true - agent, false - not agent
    function setDelegate(address _delegate, bool _isDelegate) public override {
        _onlyOwner();
        isDelegate[_delegate] = _isDelegate;
    }

    /// @notice sets grinder share numerator
    function setShares(uint16 _grinderShareNumerator, uint16 _liquidityShareNumerator) public override {
        _onlyOwner();
        grinderShareNumerator = _grinderShareNumerator;
        liquidityShareNumerator = _liquidityShareNumerator;
        require(grinderShareNumerator + liquidityShareNumerator == DENOMINATOR, "Invalid shares");
    }

    /// @notice sets grinder
    /// @param _grinder address of grinder
    function setGrinder(address payable _grinder) public override {
        _onlyOwner();
        grinder = _grinder;
    }

    //// GRAI CONFIGURATION

    /// @notice sets bridge gas limit and value
    /// @param endpointId id of the endpoint
    /// @param gasLimit gas limit for the bridge
    /// @param value value for the bridge
    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) public override {
        _onlyOwner();
        grAI.setLzReceivOptions(endpointId, gasLimit, value);
    }

    /// @notice sets multiplier numerator on grAI
    /// @dev denominator is 100% = 100_00
    /// @param multiplierNumerator numerator of multiplier
    function setMultiplierNumerator(uint256 multiplierNumerator) public override {
        _onlyOwner();
        grAI.setMultiplierNumerator(multiplierNumerator);
    }

    /// @notice sets native bridge fee numerator on grAI
    /// @dev denominator is 100% = 100_00
    /// @param nativeBridgeFeeNumerator numerator of native bridge fee
    function setNativeBridgeFee(uint256 nativeBridgeFeeNumerator) public override {
        _onlyOwner();
        grAI.setNativeBridgeFee(nativeBridgeFeeNumerator);
    }

    /// @notice sets peer address on grAI
    /// @param eid id of the peer
    /// @param peer address of the peer
    /// @dev peer is a bytes32 to accommodate non-evm chains
    function setPeer(uint32 eid, bytes32 peer) public override {
        _onlyOwner();
        grAI.setPeer(eid, peer);
    }

    //// END GRAI CONFIGURATION

    /// @notice grind 
    /// @param poolId id of pool
    function grind(uint256 poolId) public override returns (bool) {
        try poolsNFT.grind(poolId) returns (bool isGrinded) {
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
        for (uint256 i = 0; i < len; ) {
            grind(poolIds[i]);
            unchecked { ++i; }
        }
    }

    /// @notice AI grind to
    /// @dev can be called by anyone
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy
    function grindOp(uint256 poolId, uint8 op) public override returns (bool) {
        if (op <= uint8(Op.HEDGE_REBUY)) {
            try poolsNFT.grindOp(poolId, op) returns (bool isGrinded) {
                return isGrinded;
            } catch {
                return false;
            }
        } else if (op == uint8(Op.BRANCH)) {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.branch(poolId) {
                return true;
            } catch {
                return false;
            }

        } else if (op == uint8(Op.UNBRANCH)) {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.unbranch(poolId) {
                return true;
            } catch {
                return false;
            }
        }
        return false;
    }

    /// @notice batch of grindOps
    /// @param poolIds array of pool ids
    /// @param ops array of ops
    function batchGrindOp(uint256[] memory poolIds, uint8[] memory ops) public override {
        if (poolIds.length != ops.length) {
            revert InvalidLength();
        }
        uint256 len = poolIds.length;
        for (uint256 i = 0; i < len;) {
            grindOp(poolIds[i], ops[i]);
            unchecked { ++i; }
        }
    }

    /// @notice sets whole config
    /// @param poolId id of pool on poolsNFT
    /// @param config structure of config params
    function setConfig(uint256 poolId, IURUS.Config memory config) public override {
        _onlyDelegate();
        _setConfig(poolId, config);
    }

    /// @notice sets batch of whole config
    /// @param poolIds array of poolIds
    /// @param configs array of configs
    function batchSetConfig(uint256[] memory poolIds, IURUS.Config[] memory configs) public override {
        _onlyDelegate();
        if (poolIds.length != configs.length) {
            revert InvalidLength();
        }
        uint256 len = poolIds.length;
        for (uint256 i; i < len; ) {
            _setConfig(poolIds[i], configs[i]);
            unchecked { ++i; }
        }
    }

    /// @notice set config
    function _setConfig(uint256 poolId, IURUS.Config memory config) private {
        try IStrategy(poolsNFT.pools(poolId)).setConfig(config) {
            // do nothing
        } catch { 
            // skip, backend will check
        }
    }

    /// @notice sets long number max
    /// @param poolId id of pool on poolsNFT
    /// @param longNumberMax param longNumberMax on IURUS.Config
    function setLongNumberMax(uint256 poolId, uint8 longNumberMax) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setLongNumberMax(longNumberMax);
    }

    /// @notice sets hedge number max
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param hedgeNumberMax param hedgeNumberMax on IURUS.Config
    function setHedgeNumberMax(uint256 poolId, uint8 hedgeNumberMax) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setHedgeNumberMax(hedgeNumberMax);
    }

    /// @notice sets extra coef
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param extraCoef param extraCoef on IURUS.Config
    function setExtraCoef(uint256 poolId, uint256 extraCoef) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setExtraCoef(extraCoef);
    }

    /// @notice sets price volatility percent
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param priceVolatilityPercent param priceVolatilityPercent on IURUS.Config
    function setPriceVolatilityPercent(uint256 poolId, uint256 priceVolatilityPercent) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setPriceVolatilityPercent(priceVolatilityPercent);
    }

    /// @notice sets return percent
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param op operation on IURUS.Op enumeration
    /// @param returnPercent param returnPercent on IURUS.Config 
    function setOpReturnPercent(uint256 poolId, uint8 op, uint256 returnPercent) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setOpReturnPercent(op, returnPercent);
    }

    /// @notice sets fee coef
    /// @dev callable only by agent
    /// @param poolId id of pool on poolsNFT
    /// @param op operation on IURUS.Op enumeration
    /// @param feeCoef param feeCoef on IURUS.FeeConfig 
    function setOpFeeCoef(uint256 poolId, uint8 op, uint256 feeCoef) public override {
        _onlyDelegate();
        IStrategy(poolsNFT.pools(poolId)).setOpFeeCoef(op, feeCoef);
    }

    /// @notice return version of GrinderAI
    function version() external pure returns (uint256) {
        return 0;
    }

    /// @notice execute any transaction on grAI
    /// @dev callable only by owner
    /// @param target address of target
    /// @param value amount of ETH
    /// @param data calldata to target
    function executeGRAI(address target, uint256 value, bytes calldata data) external payable virtual override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = grAI.execute{value: value}(target, value, data);
    }

    /// @notice execute any transaction
    /// @param target address of target
    /// @param value amount of ETH
    /// @param data calldata to target
    function execute(address target, uint256 value, bytes calldata data) external payable virtual override returns (bool success, bytes memory result) {
        _onlyOwner();
        (success, result) = target.call{value: value}(data);
    }

    receive() external payable {
        uint256 value = msg.value;
        if (value > 0) {
            uint256 grinderShare = (value * grinderShareNumerator) / DENOMINATOR;
            bool success;
            (success, ) = grinder.call{value: grinderShare}("");
            uint256 liquidity = value - grinderShare;
            try weth.deposit{value: liquidity}() {} catch {}
        }
    }

}