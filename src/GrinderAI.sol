// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import { IToken } from "src/interfaces/IToken.sol";
import { IPoolsNFT } from "src/interfaces/IPoolsNFT.sol";
import { IAgent } from "src/interfaces/IAgent.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IStrategy, IURUS } from "src/interfaces/IStrategy.sol";
import { IGrinderAI } from "src/interfaces/IGrinderAI.sol";

/// @title Grinder Attention Intelligence Token
/// @author Triple Panic Labs. CTO Vakhtanh Chikhladze (the.vaho1337@gmail.com)
/// @notice GrinderAI ERC20 token
contract GrinderAI is ERC20, IGrinderAI {
    using SafeERC20 for IToken;

    /// @dev address of poolsNFT
    IPoolsNFT public poolsNFT;

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

    /// @dev id of crosschain adapter => address of adapter
    mapping (uint8 crosschainAdapterId => address) public crosschainAdapter;

    /// @param _poolsNFT address of grinderAI
    constructor(address _poolsNFT) ERC20("Grinder Attention Intelligence Token", "GRAI") {
        poolsNFT = IPoolsNFT(_poolsNFT);
        oneGRAI = 1e18;
        ratePerGRAI[address(0)] = 0.0001 ether; // 0.0001 ETH per 1 grAI
    }

    /// @notice return owner of grinderAI
    function owner() public view override returns (address) {
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

    //// OWNER FUNCTIONS 

    /// @notice sets rate per GRAI
    /// @dev if rate == 0, than this is not payment token
    /// @param paymentToken address of token
    /// @param rate rate for 1 GRAI
    function setRatePerGRAI(address paymentToken, uint256 rate) public override {
        _onlyOwner();
        ratePerGRAI[paymentToken] = rate;
    }

    //// END OWNER FUNCTIONS ////////////////////////////////////////////////////////////////

    //// MINT GRAI 

    /// @notice calculate payment
    /// @param paymentToken address of token
    /// @param graiAmount amount of grai
    function calcMintPayment(address paymentToken, uint256 graiAmount) public view override returns (uint256 paymentAmount) {      
        if (ratePerGRAI[paymentToken] == 0) {
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
        uint256 paymentAmount = calcMintPayment(paymentToken, graiAmount);
        if (paymentAmount > 0) {
            address _owner = owner();
            if (paymentToken == address(0)) {
                (bool success, ) = payable(_owner).call{value: paymentAmount}("");
                success;
            } else {
                IToken(paymentToken).safeTransferFrom(msg.sender, _owner, paymentAmount);
            }
            emit Pay(paymentToken, msg.sender, paymentAmount);
        }
        _mint(to, graiAmount);
        return graiAmount;
    }

    //// END MINT GRAI

    /// @notice transmit grAI for grind from `from` to `to  
    /// @dev callable only by grinderAI
    function _transmit(address from, address to, uint256 amount) internal returns (uint256) {
        if (balanceOf(from) < amount) {
            return 0;
        }
        _transfer(from, to, amount);
        return amount;
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IGrinderAI) returns (bool) {
        return ERC20.transferFrom(from, to, amount);
    }

    /// @notice direct transfer grAI
    /// @param to address of to
    /// @param amount amount of grAI
    function transfer(address to, uint256 amount) public override(ERC20, IGrinderAI) returns (bool) {
        return ERC20.transfer(to, amount);
    }

    //// GRINDING FUNCTIONS ////////////////////////////////////////////////////////////////

    /// @notice airdrops grETH to pool participants
    function _airdropGRETH(uint256 poolId) internal {
        uint256 grethAmount = ratePerGRAI[address(0)];
        poolsNFT.airdrop(poolId, grethAmount);
    }

    /// @notice grind
    /// @dev first make macromanagement, second micromamagement
    /// @param poolId id of pool
    function grind(uint256 poolId) public override returns (bool) {
        return grindTo(poolId, payable(msg.sender));
    }

    /// @notice grind
    /// @dev first makes macromanagement, second micromamagement
    /// @param poolId id of pool
    /// @param metaGrinder address of grinder
    function grindTo(uint256 poolId, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        try agent.macroOps(poolId) returns (bool _success) {
            if (_success) {
                _transmit(ownerOf, grinder, oneGRAI);
                _airdropGRETH(poolId);
            }
        } catch {
            // go on
        }
        try poolsNFT.microOps(poolId) returns (bool _success) {
            if (_success) {
                _transmit(ownerOf, grinder, oneGRAI);
                _airdropGRETH(poolId);
            }
            success = _success;
        } catch {
            success = false;
        }
        grinder = payable(address(0));
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
    /// @param poolIds array of pool ids
    /// @param metaGrinder address of grinder
    function batchGrindTo(uint256[] memory poolIds, address payable metaGrinder) public override {
        uint256 len = poolIds.length;
        for (uint256 i = 0; i < len; ) {
            grindTo(poolIds[i], metaGrinder);
            unchecked { ++i; }
        }
    } 

    /// @notice grind operation on behalf of `msg.sender`
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy; 4, 5,... agent related
    function grindOp(uint256 poolId, uint8 op) public override returns (bool) {
        return grindOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice grind operation
    /// @dev can be called by anyone, especially by grinder EOA
    /// @param poolId id of pool
    /// @param op operation on IURUS.Op enumeration; 0 - buy, 1 - sell, 2 - hedge_sell, 3 - hedge_rebuy; 4, 5,... agent related
    /// @param metaGrinder address of grinder
    function grindOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        if (op <= uint8(IURUS.Op.HEDGE_REBUY)) {
            try poolsNFT.microOp(poolId, op) returns (bool _success) {
                if (_success) {
                    _transmit(ownerOf, grinder, oneGRAI);
                    _airdropGRETH(poolId);
                }
                success = _success;
            } catch {
                success = false;
            }
        } else {
            IAgent agent = IAgent(poolsNFT.agentOf(poolId));
            try agent.macroOp(poolId, op) returns (bool _success) {
                if (_success) {
                    _transmit(ownerOf, grinder, oneGRAI);
                    _airdropGRETH(poolId);
                }
                success = _success;
            } catch {
                success = false;
            }
        }
        grinder = payable(address(0));
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

    /// @notice batch of grindOps on behalf of `metaGrinder`
    /// @param poolIds array of pool ids
    /// @param ops array of ops
    /// @param metaGrinder address of grinder
    function batchGrindOpTo(uint256[] memory poolIds, uint8[] memory ops, address payable metaGrinder) public override {
        if (poolIds.length != ops.length) {
            revert InvalidLength();
        }
        uint256 len = poolIds.length;
        for (uint256 i = 0; i < len;) {
            grindOpTo(poolIds[i], ops[i], metaGrinder);
            unchecked { ++i; }
        }
    }

    /// @notice microOp for simulation purposes
    function microOp(uint256 poolId, uint8 op) public override returns (bool) {
        return microOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice microOpTo for simulation purposes on behalf of metaGrinder
    /// @dev grinder make offchain microOp.staticCall(poolId, op) and receive success or fail of simulation
    /// @param metaGrinder address of grinder
    function microOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        if (op > uint8(IURUS.Op.HEDGE_REBUY)) {
            revert NotMicroOp();
        }
        success = poolsNFT.microOp(poolId, op);
        if (success) {
            _transmit(ownerOf, grinder, oneGRAI);
            _airdropGRETH(poolId);
        }
        grinder = payable(address(0));
    }

    /// @notice macroOp for simulation purposes
    function macroOp(uint256 poolId, uint8 op) public override returns (bool) {
        return macroOpTo(poolId, op, payable(msg.sender));
    }

    /// @notice macroOp for simulation purposes
    /// @dev grinder make offchain macroOp.staticCall(poolId, op) and receive success or fail of simulation
    /// @param metaGrinder address of grinder
    function macroOpTo(uint256 poolId, uint8 op, address payable metaGrinder) public override returns (bool success) {
        grinder = metaGrinder;
        address ownerOf = poolsNFT.ownerOf(poolId);
        IAgent agent = IAgent(poolsNFT.agentOf(poolId));
        if (op <= uint8(IURUS.Op.HEDGE_REBUY)) {
            revert NotMacroOp();
        }
        success = agent.macroOp(poolId, op);
        if (success) {
            _transmit(ownerOf, grinder, oneGRAI);
            _airdropGRETH(poolId);
        }
        grinder = payable(address(0));
    }

    //// END GRINDING FUNCTIONS

    /// @notice get intent for grinding of `account`
    /// @param account address of account
    function getIntent(address account) public view override returns (Intent memory intent) {
        uint256[] memory poolIds = poolsNFT.getPoolIdsOf(account);
        intent = Intent({
            account: account,
            grinds: balanceOf(account) / oneGRAI,
            poolIds: poolIds,
            poolInfos: poolsNFT.getPoolInfosBy(poolIds)
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

    /// @param poolId id of pool
    function getPnLShares(uint256 poolId) public view override returns (PnLShares[] memory pnlShares) {
        IURUS.PnL memory pnl = getPnL(poolId);
        IStrategy pool = IStrategy(poolsNFT.pools(poolId));
        uint256 baseTokenAmount = 0;
        if (pnl.hedgeRebuyRealtime > 0) {
            baseTokenAmount += uint256(pnl.hedgeRebuyRealtime);
        }
        baseTokenAmount += pool.getPendingYield(pool.getBaseToken());
        uint256 quoteTokenAmount;
        if (pnl.longSellRealtime + pnl.hedgeSellRealtime > 0) {
            quoteTokenAmount += uint256(pnl.longSellRealtime + pnl.hedgeSellRealtime);
        }
        quoteTokenAmount += pool.getPendingYield(pool.getQuoteToken());
        (
            address[] memory receivers,
            uint256[] memory grethAmounts
        ) = poolsNFT.calcGRETHShares(poolId, ratePerGRAI[address(0)]);
        uint256 graiAmount = balanceOf(poolsNFT.ownerOf(poolId)) >= oneGRAI ? oneGRAI : 0;
        ( , uint256[] memory baseTokenRoyalties) = poolsNFT.calcRoyaltyShares(poolId, baseTokenAmount);
        ( , uint256[] memory quoteTokenRoyalties) = poolsNFT.calcRoyaltyShares(poolId, quoteTokenAmount);
        pnlShares = new PnLShares[](4);
        pnlShares[0] = PnLShares({
            receiver: receivers[0],
            grethAmount: grethAmounts[0],
            graiAmount: 0,
            baseTokenAmount: baseTokenRoyalties[0],
            quoteTokenAmount: quoteTokenRoyalties[0]
        });
        pnlShares[1] = PnLShares({
            receiver: receivers[1],
            grethAmount: grethAmounts[1],
            graiAmount: 0,
            baseTokenAmount: baseTokenRoyalties[1],
            quoteTokenAmount: quoteTokenRoyalties[1]
        });
        pnlShares[2] = PnLShares({
            receiver: receivers[2],
            grethAmount: grethAmounts[2],
            graiAmount: 0,
            baseTokenAmount: baseTokenRoyalties[2],
            quoteTokenAmount: quoteTokenRoyalties[2]
        });
        pnlShares[3] = PnLShares({
            receiver: receivers[3] != address(0) ? receivers[3] : msg.sender,
            grethAmount: grethAmounts[3],
            graiAmount: graiAmount,
            baseTokenAmount: baseTokenRoyalties[3],
            quoteTokenAmount: quoteTokenRoyalties[3]
        });
    }

    /// @notice balance of grAI
    /// @param account address of account
    function balanceOf(address account) public view override(ERC20, IGrinderAI) returns (uint256) {
        return ERC20.balanceOf(account);
    }

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

    /// @notice execute any transaction on target smart contract
    /// @dev callable only by owner
    /// @param target address of target contract
    /// @param value amount of ETH
    /// @param data data to execute on target contract
    function execute(address target, uint256 value, bytes memory data) public payable virtual override returns (bool success, bytes memory result) {
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