// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {HypERC20} from "@hyperlane-xyz/core/token/HypERC20.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title FusionXRouter
 * @dev A simplified exchange router that performs swaps based on a fixed,
 * pre-set exchange rate between two tokens.
 * This implementation only supports direct swaps (a 2-token path) and
 * uses a simple formula for calculating the output amount.
 * It's crucial that the exchange rates are set externally and accurately.
 */
contract FusionXRouter is ISwapRouter, Ownable {
    /// @notice The decimal factor used for exchange rates (1e18), assuming rates are stored as UQ112.112 or similar fixed-point representation.
    uint256 internal constant RATE_DECIMAL = 1e18;

    /**
     * @notice Maps a token pair (tokenIn => tokenOut) to its fixed exchange rate.
     * @dev The rate is stored as a scaled integer (e.g., multiplied by RATE_DECIMAL).
     * `exchangeRate[tokenA][tokenB]` is the amount of tokenB received per 1 unit of tokenA.
     */
    mapping(address => mapping(address => uint256)) public exchangeRate;

    /**
     * @notice Constructor that sets a custom owner (EOA).
     * @dev EIP-2470 singleton factory deploys as msg.sender, so we override ownership here.
     */
    constructor(address initialOwner) Ownable() {
        _transferOwnership(initialOwner);
    }

    /// @inheritdoc ISwapRouter
    // The contract inherits from ISwapRouter, which typically defines the swap function interface.

    /// --- Admin Functions ---

    /**
     * @notice Sets the fixed exchange rate for a specific token pair.
     * @dev This function should typically be protected by an access control mechanism (e.g., `onlyOwner`).
     * The `rate` should be scaled by `RATE_DECIMAL` (1e18).
     * @param tokenIn The address of the token being exchanged (input).
     * @param tokenOut The address of the token to be received (output).
     * @param rate The new exchange rate, scaled by 1e18.
     */
    function setRate(address tokenIn, address tokenOut, uint256 rate) external onlyOwner {
        exchangeRate[tokenIn][tokenOut] = rate;
    }

    /// --- Swap Function ---

    /**
     * @notice Performs a swap of an exact amount of tokens for a minimum amount of output tokens.
     * @dev This implementation is highly simplified and only supports a **2-token path**.
     * It uses the pre-set `exchangeRate` to calculate the output amount.
     * The required tokens are pulled from `msg.sender` and the output tokens are sent to `to`.
     * @param amountIn The exact amount of input tokens to be swapped.
     * @param minAmountOut The minimum acceptable amount of output tokens. Swap will revert if less is calculated.
     * @param path An array of token addresses, where `path[0]` is `tokenIn` and `path[1]` is `tokenOut`. Must have length 2.
     * @param to The recipient address for the output tokens.
     * @return amounts An array containing the input amount (`amountIn`) and the calculated output amount (`amountOut`).
     */
    function swapExactTokensForTokens(uint256 amountIn, uint256 minAmountOut, address[] calldata path, address to)
        external
        returns (uint256[] memory amounts)
    {
        require(path.length == 2, "FusionXRouter: only supports 2-token path");

        address tokenIn = path[0];
        address tokenOut = path[1];

        uint256 rate = exchangeRate[tokenIn][tokenOut];
        require(rate > 0, "FusionXRouter: no exchange rate found");

        uint256 amountOut = rate * amountIn / RATE_DECIMAL;
        require(amountOut >= minAmountOut, "FusionXRouter: slippage too high");

        bool inputSuccess = HypERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        require(inputSuccess, "FusionXRouter: failed to pull token from adapter");

        bool outputSuccess = HypERC20(tokenOut).transfer(to, amountOut);
        require(outputSuccess, "FusionXRouter: failed to transfer token to user");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}
