// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISwapRouter {
  function setRate(
    address tokenIn,
    address tokenOut,
    uint256 rate
  ) external;

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 minAmountOut,
    address[] calldata path,
    address to
  ) external returns (uint256[] memory amounts);
}
