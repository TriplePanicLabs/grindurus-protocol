// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ILendingAdapter, IToken} from "src/interfaces/ILendingAdapter.sol";
import {IAAVEV3PoolArbitrum} from "src/interfaces/aaveV3/IAAVEV3PoolArbitrum.sol";
import {IAAVEV3AToken} from "src/interfaces/aaveV3/IAAVEV3AToken.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title AAVEV3AdapterArbitrum
/// @notice Adapter for AAVE version 3
/// @dev adapter to AAVEv3 that inherrits by Strategy. Made for Arbitrum network
contract AAVEV3AdapterArbitrum is ILendingAdapter {
    using SafeERC20 for IToken;

    /// @notice address of AAVEV3 pool
    IAAVEV3PoolArbitrum public aaveV3Pool;

    /// @dev address of Token => invested amount
    mapping(IToken token => uint256) public investedAmount;

    constructor() {}

    /// @dev constructor of AAVEV3AdapterArbitrum
    function initLending(bytes memory args) public {
        if (address(aaveV3Pool) != address(0)) {
            revert LendingInitialized();
        }
        address _aaveV3Pool = decodeLendingConstructorArgs(args);
        aaveV3Pool = IAAVEV3PoolArbitrum(_aaveV3Pool);
    }

    /// @notice encodes constrcutor params
    /// @param _aaveV3Pool address of AAVEV3Pool
    function encodeLendingConstructorArgs(
        address _aaveV3Pool
    ) public pure returns (bytes memory) {
        return abi.encode(_aaveV3Pool);
    }
    
    /// @notice decodes constrcutor params
    /// @param args encoded argument of contructor params
    function decodeLendingConstructorArgs(
        bytes memory args
    ) public pure returns (address _aaveV3Pool) {
        (_aaveV3Pool) = abi.decode(args, (address));
    }

    /// @notice checking ownership
    /// @dev should be reimplemented in inherritant contract
    function _onlyOwner() internal view virtual {}

    /// @notice sets pool
    /// @param _aaveV3Pool address of AAVEv3 pool
    function setAaveV3Pool(IAAVEV3PoolArbitrum _aaveV3Pool) public {
        _onlyOwner();
        aaveV3Pool = _aaveV3Pool;
    }

    /// @notice retruns aToken
    /// @param token underlying token
    function getAToken(IToken token) public view returns (IAAVEV3AToken) {
        IAAVEV3PoolArbitrum.ReserveData memory reserveData = aaveV3Pool
            .getReserveData(address(token));
        return IAAVEV3AToken(reserveData.aTokenAddress);
    }

    /// @dev no direct function call. Will revert
    function put(
        IToken token,
        uint256 amount
    ) public virtual override returns (uint256 putAmount) {
        token; amount; putAmount;
        revert();
    }

    /// @dev no direct function call. Will revert
    function take(
        IToken token,
        uint256 amount
    ) public virtual override returns (uint256 takeAmount) {
        token; amount; takeAmount;
        revert();
    }

    /// @notice puts in `token` to lending protocol
    /// @param token address of `baseToken` or `quoteToken`
    /// @param amount amount of `baseToken` or `quoteToken`
    /// @return putAmount amount of `baseToken` or `quoteToken` sent
    function _put(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 putAmount) {
        token.forceApprove(address(aaveV3Pool), amount);
        address onBehalfOf = address(this);
        uint256 tokenBalanceBefore = token.balanceOf(onBehalfOf);

        try aaveV3Pool.supply(address(token), amount, onBehalfOf, 0) {
            // uint16 refferalCode = 0;
            uint256 tokenBalanceAfter = token.balanceOf(onBehalfOf);
            putAmount = tokenBalanceBefore - tokenBalanceAfter;
        } catch {
            // no supply, hold token on this smart contract
            putAmount = amount;
        }
        investedAmount[token] += putAmount;
    }

    /// @notice take out `token` from lending protocol
    /// @dev burn aToken and receive Token. Rate 1 aToken : 1 Token
    /// @param token address of `baseToken` or `quoteToken`
    /// @param amount amount of `baseToken` or `quoteToken`
    /// @return takeAmount amount of `baseToken` or `quoteToken` received
    function _take(
        IToken token,
        uint256 amount
    ) internal virtual returns (uint256 takeAmount) {
        address to = address(this);
        uint256 tokenBalanceBefore = token.balanceOf(to);

        try aaveV3Pool.withdraw(address(token), type(uint256).max, to) {
            uint256 tokenBalanceAfter = token.balanceOf(to);
            uint256 tokenAmount = tokenBalanceAfter - tokenBalanceBefore; // available tokens
            uint256 investedTokenAmount = investedAmount[token];
            // distribute yield profit
            if (tokenAmount > investedTokenAmount) {
                uint256 yieldProfit = tokenAmount - investedTokenAmount;
                tokenAmount -= yieldProfit; // made tokenAmount == investmentAmount
                _distributeYieldProfit(token, yieldProfit);
            }
            if (amount > tokenAmount) {
                amount = tokenAmount;
            }
            tokenAmount -= amount;
            if (tokenAmount > 0) {
                // put back unused
                token.forceApprove(address(aaveV3Pool), tokenAmount);
                try aaveV3Pool.supply(address(token), tokenAmount, to, 0)
                {} catch {}
            }
            takeAmount = amount;
        } catch {
            // no withdraw, take token on this smart contract
            takeAmount = amount;
        }
        if (investedAmount[token] >= takeAmount) {
            investedAmount[token] -= takeAmount;
        } else {
            investedAmount[token] = 0;
        }
    }

    function _distributeYieldProfit(
        IToken token,
        uint256 profit
    ) internal virtual {}

    /// @notice calculates pending yield of `token`
    /// @dev aToken to Token is 1:1 rate
    function getPendingYield(
        IToken token
    ) public view virtual returns (uint256 yield) {
        IAAVEV3AToken aToken = getAToken(token);
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        uint256 invested = investedAmount[token];
        if (aTokenBalance > invested) {
            yield = aTokenBalance - invested;
        }
    }

}
