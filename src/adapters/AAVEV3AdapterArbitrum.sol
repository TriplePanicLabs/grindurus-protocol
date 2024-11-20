// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ILendingAdapter, IToken} from "../interfaces/ILendingAdapter.sol";
import {IAAVEV3PoolArbitrum} from "../interfaces/aaveV3/IAAVEV3PoolArbitrum.sol";
import {IAAVEV3AToken} from "../interfaces/aaveV3/IAAVEV3AToken.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Adapter for AAVE version 3
/// @dev is inherrited by strategy pool
contract AAVEV3AdapterArbitrum is ILendingAdapter {
    using SafeERC20 for IToken;

    /// @notice address of AAVEV3 pool
    IAAVEV3PoolArbitrum public aaveV3Pool;

    /// @dev address of Token => invested amount
    mapping(IToken token => uint256) public investedAmount;

    constructor(bytes memory args) {
        (address _aaveV3Pool) = decodeLendingConstructorArgs(args);
        aaveV3Pool = IAAVEV3PoolArbitrum(_aaveV3Pool);
    }

    function encodeLendingConstructorArgs(address _aaveV3Pool) public pure returns (bytes memory) {
        return abi.encode(_aaveV3Pool);
    }

    function decodeLendingConstructorArgs(bytes memory args) public pure returns (address _aaveV3Pool) {
        (_aaveV3Pool) = abi.decode(args, (address));
    }

    function _onlyOwner() internal view virtual {}

    function setPool(IAAVEV3PoolArbitrum _aaveV3Pool) public {
        _onlyOwner();
        aaveV3Pool = _aaveV3Pool;
    }

    /// @notice retruns aToken
    /// @param token underlying token
    function getAToken(IToken token) public view returns (IAAVEV3AToken) {
        IAAVEV3PoolArbitrum.ReserveData memory reserveData = aaveV3Pool.getReserveData(address(token));
        return IAAVEV3AToken(reserveData.aTokenAddress);
    }

    /// @notice puts in `token` to lending protocol
    /// @param token address of `baseToken` or `quoteToken`
    /// @param amount amount of `baseToken` or `quoteToken`
    /// @return poolTokenAmount amount of aaveV3Pool tokens received. Rate 1:1
    /// @return putAmount amount of `baseToken` or `quoteToken` sent
    function put(IToken token, uint256 amount) public override returns (uint256 poolTokenAmount, uint256 putAmount) {
        IAAVEV3AToken aToken = getAToken(token);
        token.forceApprove(address(aaveV3Pool), amount);
        address onBehalfOf = address(this);
        uint256 poolBalanceBefore = aToken.balanceOf(onBehalfOf);
        uint256 tokenBalanceBefore = token.balanceOf(onBehalfOf);

        try aaveV3Pool.supply(address(token), amount, onBehalfOf, 0) {
            // uint16 refferalCode = 0;
            _onSuccessfulPut(token, amount, onBehalfOf);
        } catch {
            revert FailPut(address(token), amount);
        }

        uint256 poolBalanceAfter = aToken.balanceOf(onBehalfOf);
        uint256 tokenBalanceAfter = token.balanceOf(onBehalfOf);
        poolTokenAmount = poolBalanceAfter - poolBalanceBefore;
        putAmount = tokenBalanceBefore - tokenBalanceAfter;
        investedAmount[token] += putAmount;
    }

    /// @notice take out `token` from lending protocol
    /// @dev burn aToken and receive Token. Rate 1 aToken : 1 Token
    /// @param token address of `baseToken` or `quoteToken`
    /// @param amount amount of `baseToken` or `quoteToken`
    /// @return poolTokenAmount amount of `aBaseToken` or `aQuoteToken` sent
    /// @return takeAmount amount of `baseToken` or `quoteToken` received
    function take(IToken token, uint256 amount) public override returns (uint256 poolTokenAmount, uint256 takeAmount) {
        harvest(token);
        if (investedAmount[token] < amount) {
            amount = investedAmount[token];
        }
        if (amount == 0) {
            return (poolTokenAmount, takeAmount);
        }
        IAAVEV3AToken aToken = getAToken(token);
        address to = address(this);
        uint256 aTokenBalanceBefore = aToken.balanceOf(to);
        uint256 tokenBalanceBefore = token.balanceOf(to);

        try aaveV3Pool.withdraw(address(token), amount, to) returns (uint256 withdrawn) {
            _onSuccessfulTake(token, amount, to, withdrawn);
        } catch {
            revert FailTake(address(token), amount);
        }

        uint256 aTokenBalanceAfter = aToken.balanceOf(to);
        uint256 tokenBalanceAfter = token.balanceOf(to);
        poolTokenAmount = aTokenBalanceBefore - aTokenBalanceAfter;
        takeAmount = tokenBalanceAfter - tokenBalanceBefore;
        investedAmount[token] -= amount;
    }

    /// @notice harvest yield and transfer it to `harvestReceiver`
    /// @return harvestedYield yield amount that have been harvested from lending
    function harvest(IToken token) public returns (uint256 harvestedYield) {
        IAAVEV3AToken aToken = getAToken(token);
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance > investedAmount[token]) {
            harvestedYield = aTokenBalance - investedAmount[token];
            try aaveV3Pool.withdraw(address(token), harvestedYield, address(this)) returns (uint256 withdrawn) {
                _distributeYieldProfit(token, withdrawn);
            } catch {
                // just not distribute
            }
        }
    }

    /// @notice harvest all yield from lending protocol
    function harvestAll() public returns (uint256 baseTokenYield, uint256 quoteTokenYield) {
        baseTokenYield = harvest(getBaseToken());
        quoteTokenYield = harvest(getQuoteToken());
    }

    function _onSuccessfulPut(IToken token, uint256 amount, address onBehalfOf) internal virtual {}

    function _onSuccessfulTake(IToken token, uint256 amount, address to, uint256 withdrawn) internal virtual {}

    function _distributeYieldProfit(IToken token, uint256 profit) internal virtual {
        if (owner() != address(this)) {
            token.safeTransfer(owner(), profit);
        }
    }

    /// @notice calculates pending yield of `token`
    function getPendingYield(IToken token) public view virtual returns (uint256 yield) {
        IAAVEV3AToken aToken = getAToken(token);
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        uint256 invested = investedAmount[token];
        if (aTokenBalance > invested) {
            yield = aTokenBalance - invested;
        }
    }

    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    function owner() public view virtual returns (address) {
        return address(this);
    }
}
