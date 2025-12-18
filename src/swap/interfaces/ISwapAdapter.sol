// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ISwapAdapter
 * @notice Defines the required interface for a DEX adapter contract.
 * An adapter acts as an intermediary, receiving tokens from the aggregator and
 * executing the actual swap call against a specific DEX router contract.
 */
interface ISwapAdapter {
    /**
     * @notice Executes the core swap logic by calling the underlying DEX router.
     * The adapter is responsible for pulling tokens from the specified 'from' address
     * and transferring the resulting 'tokenOut' amount to the 'to' address.
     * @param tokenIn The address of the token being exchanged (input token).
     * @param tokenOut The address of the token to be received (output token).
     * @param amountIn The exact amount of tokenIn to be spent.
     * @param minAmountOut The minimum acceptable amount of tokenOut required (slippage protection).
     * @param from The address from which tokenIn will be pulled (e.g., the SwapAggregator).
     * @param to The final recipient address for tokenOut (e.g., the user).
     * @return amountOut The actual amount of tokenOut received after the swap.
     */
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address from, address to)
        external
        returns (uint256 amountOut);
}
