// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import { ILendingAdapter, IToken } from "src/interfaces/ILendingAdapter.sol";
import { IAAVEV3PoolBase } from "src/interfaces/aaveV3/IAAVEV3PoolBase.sol";
import { IAAVEV3AToken } from "src/interfaces/aaveV3/IAAVEV3AToken.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title AAVEV3AdapterBase
/// @notice Adapter for AAVE version 3
/// @dev adapter to AAVEv3 that inherrits by Strategy. Made for Base network
contract AAVEV3AdapterBase is ILendingAdapter {
    using SafeERC20 for IToken;

    /// @notice address of AAVEV3 pool
    IAAVEV3PoolBase public aaveV3Pool;

    /// @dev address of Token => invested amount
    mapping(IToken token => uint256) public investedAmount;

    /// @dev constructor of AAVEV3AdapterBase
    function initLending(bytes memory args) public {
        if (address(aaveV3Pool) != address(0)) {
            revert LendingInitialized();
        }
        address _aaveV3Pool = decodeLendingConstructorArgs(args);
        aaveV3Pool = IAAVEV3PoolBase(_aaveV3Pool);
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

    /// @notice get lending params
    function getLendingParams() public view virtual override returns (bytes memory args) {
        args = encodeLendingConstructorArgs(address(aaveV3Pool));
    }

    /// @notice sets lending params
    function setLendingParams(bytes memory args) public virtual override {
        (address _aaveV3Pool) = decodeLendingConstructorArgs(args);
        aaveV3Pool = IAAVEV3PoolBase(_aaveV3Pool);
    }

    /// @notice retruns aToken
    /// @param token underlying token
    function getAToken(IToken token) public view returns (IAAVEV3AToken) {
        IAAVEV3PoolBase.ReserveData memory reserveData = aaveV3Pool
            .getReserveData(address(token));
        return IAAVEV3AToken(reserveData.aTokenAddress);
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
        uint256 tokenBalanceBefore = token.balanceOf(address(this));

        try aaveV3Pool.supply(address(token), amount, address(this), 0) {
            // uint16 refferalCode = 0;
            uint256 tokenBalanceAfter = token.balanceOf(address(this));
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
        uint256 tokenBalanceBefore = token.balanceOf(address(this));

        try aaveV3Pool.withdraw(address(token), type(uint256).max, address(this)) {
            uint256 tokenBalanceAfter = token.balanceOf(address(this));
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
                try aaveV3Pool.supply(address(token), tokenAmount, address(this), 0) {} catch {}
            }
            takeAmount = amount;
        } catch {
            // no withdraw, take token on this smart contract
            if (amount <= token.balanceOf(address(this))) {
                takeAmount = amount;
            } else {
                takeAmount = token.balanceOf(address(this));
            }
        }
        if (takeAmount > investedAmount[token]) {
            takeAmount = investedAmount[token];
        }
        investedAmount[token] -= takeAmount;
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
