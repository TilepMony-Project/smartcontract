// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapAdapter} from "./interfaces/ISwapAdapter.sol";
import {ISwapAggregator} from "./interfaces/ISwapAggregator.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title SwapAggregator
 * @dev A centralized contract responsible for routing token swaps through
 * a set of whitelisted (trusted) adapter contracts.
 * It handles the flow of tokens: pulling tokens from the user, approving the
 * adapter, and initiating the swap through the adapter.
 */
contract SwapAggregator is ISwapAggregator, Ownable {
    /**
     * @notice Mapping to track which adapter addresses are authorized to perform swaps.
     * @dev Only adapters set to `true` by the contract owner can be used for swaps via `swapWithProvider`.
     */
    mapping(address => bool) isTrustedAdapter;

    /**
     * @notice Constructor that sets the deployer as the contract owner.
     * @dev Initializes the contract by setting `msg.sender` as the initial owner, leveraging the `Ownable` contract.
     */
    constructor() Ownable() {}

    // --- Admin Functions ---

    /**
     * @notice Adds a new adapter address to the list of trusted swap providers.
     * @dev This function is restricted to the contract owner (`onlyOwner` modifier).
     * The trusted adapter will be allowed to receive token approvals from this aggregator.
     * @param _adapterAddress The address of the adapter contract to be trusted.
     */
    function addTrustedAdapter(address _adapterAddress) external onlyOwner {
        require(_adapterAddress != address(0), "SwapAggregator: zero address");
        isTrustedAdapter[_adapterAddress] = true;
    }

    /**
     * @notice Removes an adapter address from the list of trusted swap providers.
     * @dev This function is restricted to the contract owner (`onlyOwner` modifier).
     * The adapter will no longer be usable for swaps initiated through this aggregator.
     * @param _adapterAddress The address of the adapter contract to be untrusted.
     */
    function removeTrustedAdapter(address _adapterAddress) external onlyOwner {
        isTrustedAdapter[_adapterAddress] = false;
    }

    // --- Swap Function ---

    /**
     * @notice Executes a token swap by routing it through a specific trusted adapter.
     * @dev This function performs four main steps:
     * 1. **Check Trust:** Verifies `adapterAddress` is trusted.
     * 2. **Pull Tokens:** Uses `transferFrom` to pull `amountIn` of `tokenIn` from `msg.sender` (the user) to the Aggregator.
     * 3. **Approve Adapter:** Approves the `adapterAddress` to spend `amountIn` tokens from the Aggregator's balance.
     * 4. **Delegate Swap:** Calls `adapterAddress.swap(...)`, passing the Aggregator's address (`address(this)`) as the `from` parameter.
     * @param adapterAddress The address of the trusted swap adapter to use.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the expected output token.
     * @param amountIn The exact amount of input tokens to swap.
     * @param minAmountOut The minimum acceptable amount of output tokens (slippage protection).
     * @param to The final recipient address for the output tokens.
     * @return amountOut The actual amount of `tokenOut` received from the swap.
     */
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

        amountOut = ISwapAdapter(adapterAddress).swap(tokenIn, tokenOut, amountIn, minAmountOut, address(this), to);
    }
}
