// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";

/**
 * @title MerchantMoeAdapter
 * @dev An adapter contract designed to facilitate swaps by integrating with the
 * `MerchantMoeRouter`.
 * It handles pulling tokens from the user (via `transferFrom`), approving the
 * router to spend the tokens, and calling the router's swap function.
 * This structure is common in complex DEX aggregation systems where the user
 * interacts with an adapter/aggregator, not directly with the router.
 */
contract MerchantMoeAdapter is ISwapAdapter {
    /**
     * @notice Immutable reference to the `ISwapRouter` contract that performs the actual exchange.
     * @dev This is the address of the `MerchantMoeRouter` instance that this adapter utilizes.
     */
    ISwapRouter public immutable ROUTER;

    /**
     * @notice Constructor for the MerchantMoeAdapter.
     * @dev Sets the address of the underlying swap router upon deployment.
     * @param _router The address of the deployed `ISwapRouter` contract.
     */
    constructor(address _router) {
        ROUTER = ISwapRouter(_router);
    }

    /// @inheritdoc ISwapAdapter
    // The contract inherits from ISwapAdapter, which typically defines the swap function interface.

    /**
     * @notice Executes a token swap by delegating the call to the configured `ROUTER`.
     * @dev This function first pulls `amountIn` of `tokenIn` from the `from` address,
     * approves the `ROUTER` to spend the pulled tokens, and then calls
     * `ROUTER.swapExactTokensForTokens` to execute the exchange.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token.
     * @param amountIn The exact amount of input tokens to swap.
     * @param minAmountOut The minimum acceptable amount of output tokens.
     * @param from The address from which the input tokens will be pulled (typically an aggregator or the user).
     * @param to The final recipient address for the output tokens.
     * @return amountOut The actual amount of `tokenOut` received.
     */
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, address from, address to)
        external
        returns (uint256 amountOut)
    {
        bool pullSuccess = IERC20(tokenIn).transferFrom(from, address(this), amountIn);
        require(pullSuccess, "MerchantMoeAdapter: failed to pull token from aggregator to adapter");

        bool approveSuccess = IERC20(tokenIn).approve(address(ROUTER), amountIn);
        require(approveSuccess, "MerchantMoeAdapter: failed to approve router to spend the tokens");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = ROUTER.swapExactTokensForTokens(amountIn, minAmountOut, path, to);

        return amounts[1];
    }
}
