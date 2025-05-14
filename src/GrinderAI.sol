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

    /// @dev burn rate of grind
    uint256 public burnRate;

    /// @dev address of token => rate for 1 grAI
    /// @dev [rate] = amount of token / 1 grAI
    /// @dev token is address(0), this is ETH. Else ERC20 token
    /// @dev if ratePerGRAI==type(uint256).max, than payment if free on `paymentToken`
    /// @dev if ratePerGRAI==0, than this is not payment token
    mapping (address paymentToken => uint256) public ratePerGRAI;

    /// @notice initialize function
    function init(address _poolsNFT, address _grAI, address _weth) public override {
        require(
            address(poolsNFT) == address(0) &&
            address(grAI) == address(0) &&
            address(weth) == address(0)
        );
        poolsNFT = IPoolsNFT(_poolsNFT);
        grAI = IGRAI(_grAI);
        weth = IWETH9(_weth);
        grinder = payable(owner());
        grinderShareNumerator = 80_00;
        liquidityShareNumerator = 20_00;
        burnRate = 1e18; // 1 GRAI
        checkShares(grinderShareNumerator, liquidityShareNumerator);
        ratePerGRAI[address(0)] = 0.0001 ether; // 0.0001 ETH per grind
    }

    /// @notice checks that shares are valid
    function checkShares(uint16 _grinderShareNumerator, uint16 _liquidityShareNumerator) public pure {
        if (_grinderShareNumerator + _liquidityShareNumerator != DENOMINATOR) {
            revert InvalidShares();
        }
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

    //// GRINDER AI CONFIGURATION

    /// @notice sets rate per GRAI
    /// @dev if rate == 0, than this is not payment token
    /// @param paymentToken address of token
    /// @param rate rate for 1 GRAI
    function setRatePerGRAI(address paymentToken, uint256 rate) public override {
        _onlyOwner();
        ratePerGRAI[paymentToken] = rate;
    }

    /// @notice sets burn rate
    /// @dev burn rate is amount of GRAI to burn for each grind
    /// @param _burnRate amount of GRAI to burn for each grind
    function setBurnRate(uint256 _burnRate) public override {
        _onlyOwner();
        burnRate = _burnRate;
    }

    /// @notice sets grinder share numerator
    /// @dev requires that _grinderShareNumerator + _liquidityShareNumerator == DENOMINATOR
    /// @param _grinderShareNumerator numerator of grinder share
    /// @param _liquidityShareNumerator numerator of liquidity share
    function setShares(uint16 _grinderShareNumerator, uint16 _liquidityShareNumerator) public override {
        _onlyOwner();
        grinderShareNumerator = _grinderShareNumerator;
        liquidityShareNumerator = _liquidityShareNumerator;
        checkShares(grinderShareNumerator, liquidityShareNumerator);
    }

    /// @notice sets grinder
    /// @param _grinder address of grinder
    function setGrinder(address payable _grinder) public override {
        _onlyOwner();
        grinder = _grinder;
    }

    //// END GRINDER AI CONFIGURATION

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
    /// @param artificialFeeNumerator numerator of artificial fee
    function setArtificialFeeNumerator(uint32 endpointId, uint256 artificialFeeNumerator) public override {
        _onlyOwner();
        grAI.setArtificialFeeNumerator(endpointId, artificialFeeNumerator);
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

    /// @notice withdraws amount of token to `msg.sender`
    /// @dev callable only by owner
    /// @param token address of token
    /// @param amount amount of token to withdraw
    /// @return withdrawn amount of token withdrawn
    function withdraw(address token, uint256 amount) public override returns (uint256) {
        return withdrawTo(token, msg.sender, amount);
    }

    /// @notice withdraws amount of token to `to`
    /// @dev callable only by owner
    /// @param token address of token
    /// @param to address of receiver
    /// @param amount amount of token to withdraw
    /// @return withdrawn amount of token withdrawn
    function withdrawTo(address token, address to, uint256 amount) public override returns (uint256 withdrawn) {
        _onlyOwner();
        uint256 balance;
        if (token == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IToken(token).balanceOf(address(this));
        }
        if (amount > balance) {
            amount = balance;
        }
        if (token == address(0)) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) {
                revert FailTransferETH();
            }
        } else {
            IToken(token).safeTransfer(to, amount);
        }
        withdrawn = amount;
    }

    //// GRINDING FUNCTIONS

    /// @notice calculate payment
    /// @param paymentToken address of token
    /// @param graiAmount amount of grai
    function calcPayment(address paymentToken, uint256 graiAmount) public view override returns (uint256 paymentAmount) {      
        if (!isPaymentToken(paymentToken)) {
            revert NotPaymentToken();
        }
        if (ratePerGRAI[paymentToken] == type(uint256).max) { // free
            paymentAmount = 0;
        } else {
            paymentAmount = (graiAmount * ratePerGRAI[paymentToken]) / 1e18;
        }
    }

    /// @notice mints grAI on behalf of `msg.sender`
    /// @param graiAmount amount of grinds
    function mint(address paymentToken, uint256 graiAmount) public payable override returns (uint256) {
        return mintTo(paymentToken, msg.sender, graiAmount);
    }

    /// @notice mints grAI on behalf of `to`
    /// @param paymentToken address of payment token
    /// @param to address of `to`
    /// @param graiAmount amount of grinds
    function mintTo(address paymentToken, address to, uint256 graiAmount) public payable override returns (uint256) {
        uint256 paymentAmount = calcPayment(paymentToken, graiAmount);
        if (paymentAmount > 0) {
            uint256 grinderShare = (paymentAmount * grinderShareNumerator) / DENOMINATOR;
            if (paymentToken == address(0)) {
                (bool success, ) = grinder.call{value: grinderShare}("");
                success;
                // rest hold on GrinderAI
            } else {
                IToken(paymentToken).safeTransferFrom(msg.sender, address(this), grinderShare);
            }
            emit Pay(paymentToken, msg.sender, paymentAmount);
        }
        grAI.mint(to, graiAmount);
        return graiAmount;
    }

    /// @notice burns grAI of `to`
    /// @param to address of `to`
    /// @param amount amount of grAI to burn
    function _burnTo(address to, uint256 amount) internal returns (uint256) {
        if (amount > 0 && msg.sender == grinder) {
            try grAI.burn(to, amount) returns (uint256 burned) {
                return burned;
            } catch {
                return 0;
            }
        }
        return 0;
    }

    /// @notice mints grAI on behalf of `to`
    function _refundBurnTo(address to, uint256 amount) internal returns (uint256) {
        if (amount > 0 && msg.sender == grinder) {
            try grAI.mint(to, amount) returns (uint256 minted) {
                return minted;
            } catch {
                return 0;
            }
        }
        return 0;
    }

    /// @notice grind
    /// @dev first make macromanagement, second micromamagement
    /// @param poolId id of pool
    function grind(uint256 poolId) public override returns (bool success) {
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        uint256 burned = _burnTo(ownerOf, burnRate);
        try agent.unbranch(poolId) returns (uint256) {
            return true;
        } catch {
            // go on
        }
        try agent.branch(poolId) returns (uint256) {
            return true;
        } catch {
            // go on
        }
        try poolsNFT.grind(poolId) returns (bool isGrinded) {
            success = isGrinded;
        } catch {
            success = false;
        }
        if (!success) {
            _refundBurnTo(ownerOf, burned);
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

    /// @notice microOp for simulation purposes
    /// @dev grinder make offchain microOp.staticCall(poolId, op) and receive success or fail of simulation
    function microOp(uint256 poolId, uint8 op) public override returns (bool success) {
        address ownerOf = poolsNFT.ownerOf(poolId);
        uint256 burned = _burnTo(ownerOf, burnRate);
        if (op > uint8(Op.HEDGE_REBUY)) {
            revert NotMicroOp();
        } 
        success = poolsNFT.microOp(poolId, op);
        if (!success) {
            _refundBurnTo(ownerOf, burned);
        }
    }

    /// @notice macroOp for simulation purposes
    /// @dev grinder make offchain macroOp.staticCall(poolId, op) and receive success or fail of simulation
    function macroOp(uint256 poolId, uint8 op) public override returns (bool success) {
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        uint256 burned = _burnTo(ownerOf, burnRate);
        if (op == uint8(Op.BRANCH)) {
            uint256 branchPoolId = agent.branch(poolId);
            success = (branchPoolId != poolId);
        } else if (op == uint8(Op.UNBRANCH)) {
            uint256 abovePoolId = agent.unbranch(poolId);
            success = abovePoolId != poolId;
        } else {
            revert NotMacroOp();
        }
        if (!success) {
            _refundBurnTo(ownerOf, burned);
        }
    }

    /// @notice grind operation
    /// @dev can be called by anyone, especially by grinder EOA
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy, 4 - branch, 5 unbranch
    function grindOp(uint256 poolId, uint8 op) public override returns (bool success) {
        address ownerOf = poolsNFT.ownerOf(poolId);
        uint256 burned = _burnTo(ownerOf, burnRate);
        if (op <= uint8(Op.HEDGE_REBUY)) {
            try poolsNFT.microOp(poolId, op) returns (bool isGrinded) {
                success = isGrinded;
            } catch {
                success = false;
            }
        } else if (op == uint8(Op.BRANCH)) {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.branch(poolId) returns (uint256 branchPoolId) {
                success = poolId != branchPoolId;
            } catch {
                success = false;
            }
        } else if (op == uint8(Op.UNBRANCH)) {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.unbranch(poolId) returns (uint256 abovePoolId) {
                success = abovePoolId != poolId;
            } catch {
                success = false;
            }
        }
        if (!success) {
            _refundBurnTo(ownerOf, burned);
        }
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

    //// END GRINDING FUNCTIONS

    /// @notice get intent for grinding of `_account`
    /// @param _account address of account
    function getIntentOf(address account) public view override returns (
        address _account,
        uint256 _grinds,
        uint256[] memory _poolIds
    ) {
        _account = account;
        _grinds = grAI.balanceOf(account) / burnRate;
        _poolIds = poolsNFT.getPoolIdsOf(account);
    }

    /// @notice return true if `paymentToken` is payment token 
    function isPaymentToken(address paymentToken) public view override returns (bool) {
        return ratePerGRAI[paymentToken] > 0;
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