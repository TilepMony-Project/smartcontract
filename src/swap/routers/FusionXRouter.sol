// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract FusionXRouter is ISwapRouter {
  mapping(address => mapping(address => uint256)) public exchangeRate;

  function setRate(
    address tokenIn,
    address tokenOut,
    uint256 rate
  ) external {
    exchangeRate[tokenIn][tokenOut] = rate;
  }

  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 minAmountOut,
    address[] calldata path,
    address to
  ) external returns (uint256[] memory amounts) {
    require(path.length == 2, "FusionXRouter: only supports 2-token path");

    address tokenIn = path[0];
    address tokenOut = path[1];

    uint256 rate = exchangeRate[tokenIn][tokenOut];
    require(rate > 0, "FusionXRouter: no exchange rate found");

    uint256 amountOut = rate * amountIn;
    require(amountOut >= minAmountOut, "FusionXRouter: slippage too high");

    bool inputSuccess = IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
    require(inputSuccess, "FusionXRouter: failed to pull token from adapter");

    bool outputSuccess = IERC20(tokenOut).transfer(to, amountOut);
    require(outputSuccess, "FusionXRouter: failed to transfer token to user");

    amounts = new uint256[](2);
    amounts[0] = amountIn;
    amounts[1] = amountOut;
  }
}
