// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ISwapRouter
 * @notice Interface for a DEX Router that can execute swaps.
 */
interface ISwapRouter {
    /**
     * @notice Sets the exchange rate for a pair of tokens.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token.
     * @param rate The scaled exchange rate (Rate * 1e18).
     */
    function setRate(address tokenIn, address tokenOut, uint256 rate) external;

    /**
     * @notice Swaps an exact amount of input tokens for output tokens.
     * @param amountIn The exact amount of input tokens to send.
     * @param minAmountOut The minimum amount of output tokens required.
     * @param path A path of tokens, always two elements [tokenIn, tokenOut] for this router.
     * @param to The address to receive the output tokens.
     * @return amounts An array containing [amountIn, amountOut].
     */
    function swapExactTokensForTokens(uint256 amountIn, uint256 minAmountOut, address[] calldata path, address to)
        external
        returns (uint256[] memory amounts);
}
