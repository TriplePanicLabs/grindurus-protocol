// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IDexAdapter, IToken} from "src/interfaces/IDexAdapter.sol";
import {IPoolManagerArbitrum, PoolKey, Currency, IHooks, IPoolManager} from "src/interfaces/uniswapV4/IPoolManagerArbitrum.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title UniswapV3AdapterBase
/// @notice Adapter for UniswapV4
/// @dev adapter to UniswapV4 that inherrits by Strategy. Made for Arbitrum network
contract UniswapV4AdapterArbitrum is IDexAdapter {
    using SafeERC20 for IToken;

    /// @notice address of poolManager
    IPoolManagerArbitrum public poolManager;

    /// @notice fee of uniswapV4 pool
    uint24 public fee;

    constructor() {}

    /// @notice initialize dex
    /// @param args encoded params
    function initDex(
        bytes memory args
    ) public {
        if (address(poolManager) != address(0)) {
            revert DexInitialized();
        }
        (address _poolManager, uint24 _fee, address _quoteToken, address _baseToken) = decodeDexConstructorArgs(args);

        if (_quoteToken != address(0)) {
            IToken(_quoteToken).forceApprove(_poolManager, type(uint256).max);
        }
        if (_baseToken != address(0)) {
            IToken(_baseToken).forceApprove(_poolManager, type(uint256).max);
        }

        poolManager = IPoolManagerArbitrum(_poolManager);
        fee = _fee;
    }

    /// @notice encode dex constructor args
    /// @param _poolManager address of UniswapV4 pool manager
    /// @param _fee address of UniswapV3 pool fee
    /// @param _quoteToken address of quoteToken
    /// @param _baseToken address of baseToken
    function encodeDexConstructorArgs(
        address _poolManager,
        uint24 _fee,
        address _quoteToken,
        address _baseToken
    ) public pure returns (bytes memory) {
        return abi.encode(_poolManager, _fee, _quoteToken, _baseToken);
    }

    /// @notice decode dex constructor args
    /// @param args encoded args of constructor via `encodeDexConstructorArgs`
    function decodeDexConstructorArgs(
        bytes memory args
    ) public pure returns (address _poolManager, uint24 _fee, address _quoteToken, address _baseToken) {
        (_poolManager, _fee, _quoteToken, _baseToken) = abi.decode(args, (address, uint24, address, address));
    }

    function _onlyOwner() internal view virtual {}

    /// @notice swap
    /// @dev revert due to security. Can be inherrited and reimplemented
    /// @param tokenIn address of token to be swapped from
    /// @param tokenOut address of token to be swapped to
    /// @param amountIn amount of tokenIn to be swapped
    function swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) public virtual override returns (uint256 amountOut) {
        tokenIn; tokenOut; amountIn; amountOut;
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        revert(); // no direct swap
    }

    /// @notice swaps assets
    /// @param tokenIn address of tokenIn
    /// @param tokenOut address of token out
    /// @param amountIn amount of tokenIn
    /// @return amountOut amount of tokenOut
    function _swap(
        IToken tokenIn,
        IToken tokenOut,
        uint256 amountIn
    ) internal virtual returns (uint256 amountOut) {
        uint256 tokenOutBalanceBefore = tokenOut.balanceOf(address(this));

        (IToken token0, IToken token1) = address(tokenIn) < address(tokenOut)
            ? (tokenIn, tokenOut)
            : (tokenOut, tokenIn);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: fee,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: address(tokenIn) < address(tokenOut),
            amountSpecified: int256(amountIn),
            sqrtPriceLimitX96: 0
        });

        bytes memory hookData;
        poolManager.swap(key, params, hookData);

        uint256 tokenOutBalanceAfter = tokenOut.balanceOf(address(this));
        amountOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
    }

    /// @notice gets quote token
    /// @dev should be reimplemented in inherrited contract
    function getQuoteToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }

    /// @notice gets base token
    /// @dev should be reimplemented in inherrited contract
    function getBaseToken() public view virtual returns (IToken) {
        return IToken(address(0));
    }
}