// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IToken } from "src/interfaces/IToken.sol";
import { IWETH9 } from "src/interfaces/IWETH9.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IAgent } from "src/interfaces/IAgent.sol";
import { IStrategy, IURUS } from "src/interfaces/IStrategy.sol";
import { Ownable2Step, Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGRAI } from "src/interfaces/IGRAI.sol";
import { IGrinderAI } from "src/interfaces/IGrinderAI.sol";

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

    /// @dev address of grinder
    /// @dev intime variable of initiator of grind tx
    address payable public grinder;

    /// @dev 1 grAI token
    uint256 public oneGRAI;

    /// @dev address of token => rate for 1 grAI
    /// @dev [rate] = amount of token / 1 grAI
    /// @dev token is address(0), this is ETH. Else ERC20 token
    /// @dev if ratePerGRAI==type(uint256).max, than payment if free on `paymentToken`
    /// @dev if ratePerGRAI==0, than this is not payment token
    mapping (address paymentToken => uint256) public ratePerGRAI;

    /// @notice initialize function
    function init(address _poolsNFT, address _grAI) public override {
        require(
            address(poolsNFT) == address(0) &&
            address(grAI) == address(0)
        );
        poolsNFT = IPoolsNFT(_poolsNFT);
        grAI = IGRAI(_grAI);
        oneGRAI = 1e18; // 1 GRAI
        ratePerGRAI[address(0)] = 0.0001 ether; // 0.0001 ETH per 1 grAI
    }

    /// @notice return owner of grinderAI
    function owner() public view returns (address payable) {
        try poolsNFT.owner() returns(address payable _owner){
            return _owner;
        } catch {
            return payable(address(poolsNFT));
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

    //// END GRAI CONFIGURATION ////////////////////////////////////////////////////////////////

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
            address payable _owner = owner();
            if (paymentToken == address(0)) {
                (bool success, ) = _owner.call{value: paymentAmount}("");
                success;
            } else {
                IToken(paymentToken).safeTransferFrom(msg.sender, _owner, paymentAmount);
            }
            emit Pay(paymentToken, msg.sender, paymentAmount);
        }
        grAI.mint(to, graiAmount);
        return graiAmount;
    }

    /// @notice transmit grAI from `from` to `to`
    /// @param to address of `to`
    /// @param amount amount of grAI to burn
    function _transmit(address from, address to, uint256 amount) internal returns (uint256 transmited) {
        if (amount > 0) {
            transmited = grAI.transmit(from, to, amount);
        }
    }

    /// @notice grind
    /// @dev first make macromanagement, second micromamagement
    /// @param poolId id of pool
    function grind(uint256 poolId) public override returns (bool) {
        return grindTo(poolId, payable(msg.sender));
    }

    /// @notice grind with defined 
    /// @dev first make macromanagement, second micromamagement
    /// @param poolId id of pool
    function grindTo(uint256 poolId, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        uint256 transmited = _transmit(ownerOf, grinder, oneGRAI);
        try agent.asyncWithdraw(poolId) returns (uint256) {
            return true;
        } catch {
            // go on
        }
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
        try poolsNFT.microOps(poolId) returns (bool isGrinded) {
            success = isGrinded;
        } catch {
            success = false;
        }
        if (!success) {
            _transmit(grinder, ownerOf, transmited);
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
    function microOp(uint256 poolId, uint8 op) public override returns (bool) {
        return microOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice microOpTo for simulation purposes on behalf of metaGrinder
    /// @dev grinder make offchain microOp.staticCall(poolId, op) and receive success or fail of simulation
    function microOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        uint256 transmited = _transmit(ownerOf, grinder, oneGRAI);
        if (op > uint8(Op.HEDGE_REBUY)) {
            revert NotMicroOp();
        }
        success = poolsNFT.microOp(poolId, op);
        if (!success) {
            _transmit(grinder, ownerOf, transmited);
        }
    }

    /// @notice macroOp for simulation purposes
    function macroOp(uint256 poolId, uint8 op) public override returns (bool) {
        return macroOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice macroOp for simulation purposes
    /// @dev grinder make offchain macroOp.staticCall(poolId, op) and receive success or fail of simulation
    function macroOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        uint256 transmited = _transmit(ownerOf, grinder, oneGRAI);
        if (op == uint8(Op.BRANCH)) {
            uint256 branchPoolId = agent.branch(poolId);
            success = (branchPoolId != poolId);
        } else if (op == uint8(Op.UNBRANCH)) {
            uint256 abovePoolId = agent.unbranch(poolId);
            success = abovePoolId != poolId;
        } else if (op == uint8(Op.ASYNC_WITHDRAW)) {
            uint256 withdrawnPoolId = agent.asyncWithdraw(poolId);
            success = withdrawnPoolId == poolId;
        } else {
            revert NotMacroOp();
        }
        if (!success) {
            _transmit(grinder, ownerOf, transmited);
        }
    }

    /// @notice grind operation on behalf of `msg.sender`
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy, 4 - branch, 5 unbranch
    function grindOp(uint256 poolId, uint8 op) public override returns (bool) {
        return grindOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice grind operation
    /// @dev can be called by anyone, especially by grinder EOA
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy, 4 - branch, 5 unbranch
    function grindOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        uint256 transmited = _transmit(ownerOf, grinder, oneGRAI);
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
        } else if (op == uint8(Op.ASYNC_WITHDRAW)) {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.asyncWithdraw(poolId) returns (uint256 withdrawnPoolId) {
                success = withdrawnPoolId == poolId;
            } catch {
                success = false;
            }
        }
        if (!success) {
            _transmit(grinder, ownerOf, transmited);
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

    /// @notice return estimated profits and loses of pool with poolId
    /// @param poolId id of pool on poolsNFT
    function getPnL(uint256 poolId) public view override returns (IURUS.PnL memory) {
        IStrategy pool = IStrategy(poolsNFT.pools(poolId));
        return pool.getPnL();
    }

    /// @notice return batch of estimated profits and loses of poolIds
    function getPnLBy(uint256[] memory poolIds) public view override returns (IURUS.PnL[] memory pnls) {
        uint256 len = poolIds.length;
        for (uint256 i = 0; i < len;) {
            pnls[i] = getPnL(poolIds[i]);
            unchecked { ++i; }
        }
    }

    /// @notice get intent for grinding of `account`
    /// @param account address of account
    function getIntent(address account) public view override returns (Intent memory intent) {
        intent = Intent({
            account: account,
            grinds: grAI.balanceOf(account) / oneGRAI,
            poolIds: poolsNFT.getPoolIdsOf(account)
        });
    }

    /// @notice get intents for grinding of `accounts`
    /// @param accounts array of accounts
    function getIntents(address[] memory accounts) public view override returns (Intent[] memory intents) {
        uint256 len = accounts.length;
        intents = new Intent[](len);
        for (uint256 i; i < len; ) {
            intents[i] = getIntent(accounts[i]);
            unchecked { ++i; }
        }
    }

    /// @notice return true if `paymentToken` is payment token 
    function isPaymentToken(address paymentToken) public view override returns (bool) {
        return ratePerGRAI[paymentToken] > 0;
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
            address _owner = owner();
            (bool success, ) = _owner.call{value: value}("");
            success;
        }
    }

}