// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISwapAggregator {
  function swapWithProvider(
    address adapterAddress,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address to
  ) external returns (uint256 amountOut);
}
