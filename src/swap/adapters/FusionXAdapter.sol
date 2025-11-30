// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

contract FusionXAdapter is ISwapAdapter {
    ISwapRouter public immutable ROUTER;

    constructor(address _router) {
        ROUTER = ISwapRouter(_router);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address from, address to)
        external
        returns (uint256 amountOut)
    {
        bool pullSuccess = IERC20(tokenIn).transferFrom(from, address(this), amountIn);
        require(pullSuccess, "FusionXAdapter: failed to pull token from aggregator to adapter");

        bool approveSuccess = IERC20(tokenIn).approve(address(ROUTER), amountIn);
        require(approveSuccess, "FusionXAdapter: failed to approve router to spend the tokens");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(amountIn, minAmountOut, path, to);

        return amounts[1];
    }
}
