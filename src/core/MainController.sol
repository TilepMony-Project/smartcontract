// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMainController} from "../interfaces/IMainController.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

// Interfaces for interaction
import {ISwapAggregator} from "../swap/interfaces/ISwapAggregator.sol";
// YieldRouter doesn't have an interface file yet, so we import the contract or define a minimal interface here.
// For cleaner code, let's define a minimal interface for YieldRouter interaction.
interface IYieldRouter {
    function deposit(
        address adapter,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256);
}

interface IMintableToken {
    function giveMe(uint256 amount) external;
}

contract MainController is IMainController, ReentrancyGuard, Ownable {
    constructor(address _owner) Ownable(_owner) {}

    function executeWorkflow(
        Action[] calldata actions,
        address initialToken,
        uint256 initialAmount
    ) external payable override nonReentrant {
        // 1. Pull initial funds
        if (initialAmount > 0) {
            if (initialToken == address(0)) {
                require(msg.value == initialAmount, "Invalid ETH amount");
            } else {
                IERC20(initialToken).transferFrom(
                    msg.sender,
                    address(this),
                    initialAmount
                );
            }
        }

        // 2. Loop through actions
        for (uint256 i = 0; i < actions.length; i++) {
            _executeAction(i, actions[i]);
        }

        emit WorkflowExecuted(msg.sender, actions.length);
    }

    function _executeAction(uint256 index, Action calldata action) internal {
        uint256 inputAmount = 0;
        address inputToken = address(0);

        // Decode input token from data to calculate balance
        // Note: This decoding depends on the standard encoding we expect from the frontend.
        // SWAP: (adapter, tokenIn, tokenOut, amountIn, minAmountOut, to) -> We need tokenIn
        // YIELD: (adapter, token, amount, data) -> We need token

        // However, the `data` in `Action` is the raw calldata for the target function (e.g. swapWithProvider).
        // To make this dynamic, we need to know WHICH token to check balance for.
        // OPTION A: Pass `inputToken` in the Action struct.
        // OPTION B: Decode based on ActionType.

        // Let's go with Option B, but we need to be careful about decoding.
        // The `data` field in `Action` is passed DIRECTLY to the aggregator.
        // So we need to decode it here just to find the token address.

        if (action.actionType == ActionType.SWAP) {
            // swapWithProvider(adapter, tokenIn, tokenOut, amountIn, minAmountOut, to)
            (address adapter, address tokenIn, , , , ) = abi.decode(
                action.data,
                (address, address, address, uint256, uint256, address)
            );
            inputToken = tokenIn;
            inputAmount = _calculateInputAmount(
                tokenIn,
                action.inputAmountPercentage
            );

            // Approve Aggregator
            IERC20(tokenIn).approve(action.targetContract, inputAmount);

            // Execute Swap
            // We need to re-encode the data with the ACTUAL inputAmount
            // This is tricky because `action.data` has the old amount.
            // We should reconstruct the call.

            // BETTER APPROACH:
            // The `action.data` should NOT contain the amount if we are calculating it dynamically.
            // OR we decode, update amount, and re-encode.

            (, , address tokenOut, , uint256 minAmountOut, address to) = abi
                .decode(
                    action.data,
                    (address, address, address, uint256, uint256, address)
                );

            uint256 outputAmount = ISwapAggregator(action.targetContract)
                .swapWithProvider(
                    adapter,
                    tokenIn,
                    tokenOut,
                    inputAmount,
                    minAmountOut,
                    to == address(0) ? address(this) : to // Default to keeping funds in Controller for next step
                );

            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                outputAmount
            );
        } else if (action.actionType == ActionType.YIELD) {
            // deposit(adapter, token, amount, data)
            // Note: The `data` inside `deposit` is the adapter-specific data.
            (address adapter, address token, , bytes memory adapterData) = abi
                .decode(action.data, (address, address, uint256, bytes));
            inputToken = token;
            inputAmount = _calculateInputAmount(
                token,
                action.inputAmountPercentage
            );

            // Approve Router
            IERC20(token).approve(action.targetContract, inputAmount);

            // Execute Deposit
            uint256 outputAmount = IYieldRouter(action.targetContract).deposit(
                adapter,
                token,
                inputAmount,
                adapterData
            );
            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                outputAmount
            );
        } else if (action.actionType == ActionType.TRANSFER) {
            // Transfer logic: data contains (token)
            (address token) = abi.decode(action.data, (address));
            inputToken = token;
            inputAmount = _calculateInputAmount(
                token,
                action.inputAmountPercentage
            );

            IERC20(token).transfer(action.targetContract, inputAmount);
            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                0
            );
            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                0
            );
        } else if (action.actionType == ActionType.MINT) {
            // mint: data contains (token, amount)
            (address token, uint256 amount) = abi.decode(
                action.data,
                (address, uint256)
            );
            inputToken = token;
            // For mint, inputAmount is 0 from the controller's perspective (it's created from thin air)
            // But we can track the minted amount as outputAmount

            IMintableToken(token).giveMe(amount);

            emit ActionExecuted(index, action.actionType, token, 0, amount);
        }
    }

    function _calculateInputAmount(
        address token,
        uint256 percentage
    ) internal view returns (uint256) {
        uint256 balance;
        if (token == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
        return (balance * percentage) / 10000;
    }

    // Allow receiving ETH
    receive() external payable {}
}
