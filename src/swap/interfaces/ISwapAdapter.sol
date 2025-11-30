// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ISwapAdapter {
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address from, address to)
        external
        returns (uint256 amountOut);
}
