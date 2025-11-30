// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapAdapter} from "./interfaces/ISwapAdapter.sol";
import {ISwapAggregator} from "./interfaces/ISwapAggregator.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract SwapAggregator is ISwapAggregator, Ownable {
  mapping(address => bool) isTrustedAdapter;

  constructor() Ownable(msg.sender) {}
  
  function addTrustedAdapter(address _adapterAddress) external onlyOwner {
    require(_adapterAddress != address(0), "SwapAggregator: zero address");
    isTrustedAdapter[_adapterAddress] = true;
  }

  function removeTrustedAdapter(address _adapterAddress) external onlyOwner {
    isTrustedAdapter[_adapterAddress] = false;
  }

  function swapWithProvider(
    address adapterAddress,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address to
  ) external returns (uint256 amountOut) {
    require(isTrustedAdapter[adapterAddress], "SwapAggregator: untrusted adapter");

    bool pullSuccess = IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
    require(pullSuccess, "SwapAggregator: failed to pull token from user to aggregator");

    bool approveSuccess = IERC20(tokenIn).approve(adapterAddress, amountIn);
    require(approveSuccess, "SwapAggregator: failed to approve adapter to spend the tokens");

    amountOut = ISwapAdapter(adapterAddress).swap(
      tokenIn,
      tokenOut,
      amountIn,
      minAmountOut,
      address(this),
      to
    );
  }
}
