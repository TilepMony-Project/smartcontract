// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMainController} from "../interfaces/IMainController.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

// Interfaces for interaction
// Interfaces for interaction
import {ISwapAggregator} from "../swap/interfaces/ISwapAggregator.sol";

interface IYieldRouter {
    function deposit(address adapter, address token, uint256 amount, bytes calldata data)
        external
        returns (uint256, address);

    function withdraw(address adapter, address shareToken, address token, uint256 amount, bytes calldata data)
        external
        returns (uint256);
}

// Interfaces for interaction
interface IBridgeRouter {
    function bridge(
        address _tokenAddress,
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _additionalData
    ) external payable;
}

interface IMintableToken {
    function giveMe(uint256 amount) external;
}

contract MainController is IMainController, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    constructor(address _owner) Ownable() {}

    function executeWorkflow(Action[] calldata actions, address initialToken, uint256 initialAmount)
        external
        payable
        override
        nonReentrant
    {
        // 1. Pull initial funds
        if (initialAmount > 0) {
            if (initialToken == address(0)) {
                require(msg.value == initialAmount, "Invalid ETH amount");
            } else {
                IERC20(initialToken).safeTransferFrom(msg.sender, address(this), initialAmount);
            }
        }

        // Track the output of the previous action
        address lastOutputToken = initialToken;

        // 2. Loop through actions
        for (uint256 i = 0; i < actions.length; i++) {
            (, address outputToken) = _executeAction(i, actions[i], lastOutputToken);
            // If the action returned a valid token (or if it kept the same token implicitly)
            // we update lastOutputToken.
            // Note: Some actions like TRANSFER might return address(0) if they don't produce new tokens.
            // But if TRANSFER(address(0)) is used, it consumes the token.
            // Let's refine the logic: each action SHOULD return what token it holds/outputs.
            lastOutputToken = outputToken;
        }

        emit WorkflowExecuted(msg.sender, actions.length);
    }

    function _executeAction(uint256 index, Action calldata action, address previousOutputToken)
        internal
        returns (uint256, address)
    {
        uint256 inputAmount = 0;
        address inputToken = address(0);

        if (action.actionType == ActionType.SWAP) {
            (address adapter, address tokenIn,,,,) =
                abi.decode(action.data, (address, address, address, uint256, uint256, address));
            // Dynamic Token Resolution for SWAP (Optional, but good for consistency)
            if (tokenIn == address(0)) {
                inputToken = previousOutputToken;
            } else {
                inputToken = tokenIn;
            }

            inputAmount = _calculateInputAmount(inputToken, action.inputAmountPercentage);

            // Approve Aggregator
            IERC20(inputToken).forceApprove(action.targetContract, inputAmount);

            // Execute Swap
            (,, address tokenOut,, uint256 minAmountOut, address to) =
                abi.decode(action.data, (address, address, address, uint256, uint256, address));

            uint256 outputAmount = ISwapAggregator(action.targetContract)
                .swapWithProvider(
                    adapter, inputToken, tokenOut, inputAmount, minAmountOut, to == address(0) ? address(this) : to
                );

            emit ActionExecuted(index, action.actionType, action.targetContract, inputAmount, outputAmount);
            return (outputAmount, tokenOut);
        } else if (action.actionType == ActionType.YIELD) {
            (address adapter, address token,, bytes memory adapterData) =
                abi.decode(action.data, (address, address, uint256, bytes));

            if (token == address(0)) {
                inputToken = previousOutputToken;
            } else {
                inputToken = token;
            }

            inputAmount = _calculateInputAmount(inputToken, action.inputAmountPercentage);

            // Approve Router
            IERC20(inputToken).forceApprove(action.targetContract, inputAmount);

            // Execute Deposit
            (uint256 outputAmount, address shareToken) =
                IYieldRouter(action.targetContract).deposit(adapter, inputToken, inputAmount, adapterData);

            emit ActionExecuted(index, action.actionType, action.targetContract, inputAmount, outputAmount);
            // Return the share token so next action can use it
            return (outputAmount, shareToken);
        } else if (action.actionType == ActionType.TRANSFER) {
            (address token) = abi.decode(action.data, (address));

            // Dynamic Token Resolution
            if (token == address(0)) {
                inputToken = previousOutputToken;
            } else {
                inputToken = token;
            }

            inputAmount = _calculateInputAmount(inputToken, action.inputAmountPercentage);

            IERC20(inputToken).safeTransfer(action.targetContract, inputAmount);
            emit ActionExecuted(index, action.actionType, action.targetContract, inputAmount, 0);
            // Transfer consumes the token (sends it away).
            // We return address(0) or potentially the remaining token if typical usage?
            // Usually if we transfer, we don't have it anymore for chaining unless we split.
            return (0, inputToken);
        } else if (action.actionType == ActionType.MINT) {
            (address token, uint256 amount) = abi.decode(action.data, (address, uint256));
            inputToken = token;
            IMintableToken(token).giveMe(amount);
            emit ActionExecuted(index, action.actionType, token, 0, amount);
            // Mint makes 'token' available
            return (amount, token);
        } else if (action.actionType == ActionType.YIELD_WITHDRAW) {
            (address adapter, address shareToken, address underlyingToken,, bytes memory adapterData) =
                abi.decode(action.data, (address, address, address, uint256, bytes));

            if (shareToken == address(0)) {
                inputToken = previousOutputToken;
            } else {
                inputToken = shareToken;
            }

            // Calculate input amount based on USER'S balance is weird if we are chaining.
            // If we are chaining, we should use 'this' balance.
            // BUT, the existing logic pulled from USER.
            // "Pull shares from User" logic (lines 182-187) assumes user holds shares.
            // If we are chaining, 'this' holds shares.
            // Let's support both? Or rather, if inputToken is in 'this', use it.

            // For now, let's keep the existing logic for non-chained (explicit shareToken)
            // But if shareToken is address(0), we assume it's in 'this'.

            if (shareToken == address(0)) {
                // It's already in the contract from previous step
                inputAmount = _calculateInputAmount(inputToken, action.inputAmountPercentage);
            } else {
                // Original logic: Pull from user
                uint256 userShareBalance = IERC20(shareToken).balanceOf(msg.sender);
                inputAmount = (userShareBalance * action.inputAmountPercentage) / 10000;
                IERC20(shareToken).safeTransferFrom(msg.sender, address(this), inputAmount);
            }

            // Approve Router
            IERC20(inputToken).forceApprove(action.targetContract, inputAmount);

            // Execute Withdraw
            uint256 outputAmount = IYieldRouter(action.targetContract)
                .withdraw(
                    adapter,
                    inputToken, // shareToken
                    underlyingToken,
                    inputAmount,
                    adapterData
                );

            emit ActionExecuted(index, action.actionType, action.targetContract, inputAmount, outputAmount);
            // Returns underlying token
            return (outputAmount, underlyingToken);
        } else if (action.actionType == ActionType.BRIDGE) {
            (address token, uint32 destination, bytes32 recipient, bytes memory additionalData) =
                abi.decode(action.data, (address, uint32, bytes32, bytes));

            if (token == address(0)) {
                inputToken = previousOutputToken;
            } else {
                inputToken = token;
            }

            inputAmount = _calculateInputAmount(inputToken, action.inputAmountPercentage);

            // Approve Bridge Router
            IERC20(inputToken).forceApprove(action.targetContract, inputAmount);

            // Execute Bridge
            // Note: If the bridge requires a fee, msg.value should have been passed to executeWorkflow
            // However, implementing dynamic fee passing from the original msg.value is complex in a loop.
            // For now, we assume the specific bridge function might not need ETH if it's just ERC20 bridging,
            // OR the contract holds enough ETH.
            // If the bridge function is payable, we can pass 0 or a specific amount if we had it.
            // Ideally, we'd have a 'nativeFee' field or pull it from 'additionalData'.
            // Here we just call it.

            IBridgeRouter(action.targetContract).bridge{value: 0}(
                inputToken, destination, recipient, inputAmount, additionalData
            );

            emit ActionExecuted(index, action.actionType, action.targetContract, inputAmount, 0);
            return (0, address(0));
        }
        return (0, address(0));
    }

    function _calculateInputAmount(address token, uint256 percentage) internal view returns (uint256) {
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
