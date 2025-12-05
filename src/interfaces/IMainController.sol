// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMainController {
    enum ActionType {
        SWAP,
        YIELD,
        BRIDGE,
        TRANSFER,
        MINT,
        YIELD_WITHDRAW
    }

    struct Action {
        ActionType actionType;
        address targetContract; // SwapAggregator, YieldRouter, BridgeManager, or Recipient
        bytes data; // Encoded function call
        uint256 inputAmountPercentage; // Basis points (0-10000)
    }

    event WorkflowExecuted(address indexed user, uint256 actionsCount);
    event ActionExecuted(
        uint256 indexed index,
        ActionType actionType,
        address target,
        uint256 inputAmount,
        uint256 outputAmount
    );

    function executeWorkflow(
        Action[] calldata actions,
        address initialToken,
        uint256 initialAmount
    ) external payable;
}
