// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ISwapAggregator
 * @notice Defines the required interface for a decentralized exchange (DEX) aggregator contract.
 * The aggregator's primary role is to coordinate token swaps by selecting the best route
 * and delegating execution to specific ISwapAdapter contracts.
 */
interface ISwapAggregator {
    /**
     * @notice Executes a token swap by delegating the call to a specific, registered swap adapter.
     * This function should handle necessary token approvals/transfers to and from the adapter.
     * * @param adapterAddress The address of the specific ISwapAdapter contract (e.g., MerchantMoeAdapter)
     * that is responsible for calling the underlying DEX router.
     * @param tokenIn The address of the token to be swapped (input token).
     * @param tokenOut The address of the token to be received (output token).
     * @param amountIn The exact amount of tokenIn to be swapped.
     * @param minAmountOut The minimum amount of tokenOut required to prevent excessive slippage.
     * @param to The address that will receive the tokenOut.
     * @return amountOut The actual amount of tokenOut received after the swap is executed by the adapter.
     */
    function swapWithProvider(
        address adapterAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external returns (uint256 amountOut);
}
