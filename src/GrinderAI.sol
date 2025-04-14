// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {IToken} from "src/interfaces/IToken.sol";
import {IPoolsNFT} from "src/interfaces/IPoolsNFT.sol";
import {IStrategy, IURUS} from "src/interfaces/IStrategy.sol";
import {Ownable2Step, Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGRAI} from "src/interfaces/IGRAI.sol";
import {IGrinderAI} from "src/interfaces/IGrinderAI.sol";
import {IIntentsNFT} from "src/interfaces/IIntentsNFT.sol";

/// @title GrinderAI
/// @notice provide transpanet mechanism for effective interaction with GrindURUS protocol via AI agent
contract GrinderAI is IGrinderAI {
    using SafeERC20 for IToken;

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

    /// @dev address of intentNFT
    IIntentsNFT public intentsNFT;

    /// @dev address of grAI
    IGRAI public grAI;

    /// @dev address of account => is agent
    mapping (address account => bool) public isAgent;

    /// @dev address of account => amount of minted grAI
    mapping (address account => uint256) public mintedGrinds;

    /// @notice initialize function
    function init(address _poolsNFT, address _intentsNFT, address _grAI) public {
        require(address(poolsNFT) == address(0) && address(intentsNFT) == address(0) && address(grAI) == address(0));
        poolsNFT = IPoolsNFT(_poolsNFT);
        intentsNFT = IIntentsNFT(_intentsNFT);
        grAI = IGRAI(_grAI);
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

    /// @notice sets pools NFT
    /// @param _poolsNFT address poolsNFT 
    function setPoolsNFT(address _poolsNFT) public {
        _onlyOwner();
        poolsNFT = IPoolsNFT(_poolsNFT);
    }

    /// @notice sets intents NFT
    /// @param _intentsNFT address intentsNFT 
    function setIntentsNFT(address _intentsNFT) public {
        _onlyOwner();
        intentsNFT = IIntentsNFT(_intentsNFT);
    }

    /// @notice sets GRAI token
    /// @param _grAI address of grAI
    function setGRAI(address _grAI) public {
        _onlyOwner();
        grAI = IGRAI(_grAI);
    }

    /// @notice sets bridge gas limit and value
    /// @param endpointId id of the endpoint
    /// @param gasLimit gas limit for the bridge
    /// @param value value for the bridge
    function setLzReceivOptions(uint32 endpointId, uint128 gasLimit, uint128 value) public override{
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

    /// @notice mints grAI token to the `msg.sender` of grinds
    function mint() public returns (uint256, uint256) {
        return mintTo(msg.sender);
    }

    /// @notice mints grAI token to the `account` of grinds
    /// @param account address of account
    function mintTo(address account) public returns (uint256 graiAmount, uint256 grindsGap) {
        (graiAmount, grindsGap) = calcMintTo(account);
        if (grindsGap > 0) {
            try grAI.mint(account, graiAmount) {
                mintedGrinds[account] += grindsGap;
            } catch {}
        }
    }

    /// @notice calculates grAI amount to mint
    /// @param account address of account
    function calcMintTo(address account) public view override returns (uint256 graiAmount, uint256 grindsGap) {
        (,uint256 grinds,) = intentsNFT.getIntentOf(account);
        if (mintedGrinds[account] < grinds) {
            grindsGap = grinds - mintedGrinds[account];
            graiAmount = grindsGap * 1e18;
        }
    }

    /// @notice AI deposit
    /// @param strategyId id of strategy
    /// @param baseToken address of base token
    /// @param quoteToken address of quote token
    /// @param quoteTokenAmounts array of quote token amounts
    function deposit(
        uint16 strategyId,
        address quoteToken,
        address baseToken,
        uint256[] memory quoteTokenAmounts
    ) public returns (uint256[] memory poolIds) {
        poolIds = depositTo(
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
    function depositTo(
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
        _setConfig(poolId, config);
    }

    /// @notice sets batch of whole config
    /// @param poolIds array of poolIds
    /// @param configs array of configs
    function batchSetConfig(uint256[] memory poolIds, IURUS.Config[] memory configs) public override {
        _onlyAgent();
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

    /// @notice return version of GrinderAI
    function version() external pure returns (uint256) {
        return 0;
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
        if (msg.value > 0) {
            bool success;
            (success, ) = address(owner()).call{value: msg.value}("");
        }
    }

}