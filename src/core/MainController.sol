// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMainController} from "../interfaces/IMainController.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
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

    function withdraw(
        address adapter,
        address shareToken,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (uint256);
}

interface IMintableToken {
    function giveMe(uint256 amount) external;
}

contract MainController is IMainController, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

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
                IERC20(initialToken).safeTransferFrom(
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

        if (action.actionType == ActionType.SWAP) {
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
            IERC20(tokenIn).forceApprove(action.targetContract, inputAmount);

            // Execute Swap
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
                    to == address(0) ? address(this) : to
                );

            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                outputAmount
            );
        } else if (action.actionType == ActionType.YIELD) {
            (address adapter, address token, , bytes memory adapterData) = abi
                .decode(action.data, (address, address, uint256, bytes));
            inputToken = token;
            inputAmount = _calculateInputAmount(
                token,
                action.inputAmountPercentage
            );

            // Approve Router
            IERC20(token).forceApprove(action.targetContract, inputAmount);

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
            (address token) = abi.decode(action.data, (address));
            inputToken = token;
            inputAmount = _calculateInputAmount(
                token,
                action.inputAmountPercentage
            );

            IERC20(token).safeTransfer(action.targetContract, inputAmount);
            emit ActionExecuted(
                index,
                action.actionType,
                action.targetContract,
                inputAmount,
                0
            );
        } else if (action.actionType == ActionType.MINT) {
            (address token, uint256 amount) = abi.decode(
                action.data,
                (address, uint256)
            );
            inputToken = token;
            IMintableToken(token).giveMe(amount);
            emit ActionExecuted(index, action.actionType, token, 0, amount);
        } else if (action.actionType == ActionType.YIELD_WITHDRAW) {
            (
                address adapter,
                address shareToken,
                address underlyingToken,
                ,
                bytes memory adapterData
            ) = abi.decode(
                    action.data,
                    (address, address, address, uint256, bytes)
                );

            inputToken = shareToken;

            // Calculate input amount based on USER'S balance
            uint256 userShareBalance = IERC20(shareToken).balanceOf(msg.sender);
            inputAmount =
                (userShareBalance * action.inputAmountPercentage) /
                10000;

            // Pull shares from User
            IERC20(shareToken).safeTransferFrom(
                msg.sender,
                address(this),
                inputAmount
            );

            // Approve Router
            IERC20(shareToken).forceApprove(action.targetContract, inputAmount);

            // Execute Withdraw
            uint256 outputAmount = IYieldRouter(action.targetContract).withdraw(
                adapter,
                shareToken,
                underlyingToken,
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
