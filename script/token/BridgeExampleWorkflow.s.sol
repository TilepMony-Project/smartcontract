// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Common.sol";
import "./TokenProfileScript.sol";
import {TokenHypERC20} from "../../src/token/TokenHypERC20.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

/// @notice Example: bridge tokens using transferRemote with workflow execution.
/// This script demonstrates how to use enhanced token bridging with workflow capabilities.
contract BridgeExampleWorkflow is TokenProfileScript {
    using TypeCasts for address;

    function run() external payable {
        string memory profile = _activeProfile();
        console2.log("Using token profile:", profile);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = _tokenAddressForChain(profile, block.chainid);
        TokenHypERC20 token = TokenHypERC20(tokenAddr);

        uint32 destination = uint32(vm.envUint("DEST_DOMAIN"));
        address recipient = vm.envAddress("RECIPIENT");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 gasPayment = vm.envUint("GAS_PAYMENT");

        // Workflow configuration
        bool useWorkflow = vm.envOr("USE_WORKFLOW", false);
        address workflowExecutor = _profileAddress(profile, "WORKFLOW_EXECUTOR", "WORKFLOW_EXECUTOR", address(0));

        bytes memory additionalData;
        if (useWorkflow && workflowExecutor != address(0)) {
            // Create workflow actions based on environment variables
            additionalData = _createWorkflowData(workflowExecutor);
            console2.log("Using workflow execution");
            console2.log("Executor:", workflowExecutor);
        } else {
            // Use regular additional data if provided
            additionalData = vm.envOr("ADDITIONAL_DATA", bytes(""));
            if (additionalData.length > 0) {
                console2.log("Using additional data, length:", additionalData.length);
            }
        }

        vm.startBroadcast(pk);

        bytes32 msgId;
        if (additionalData.length > 0) {
            msgId = token.transferRemoteWithPayload{value: gasPayment}(
                destination, recipient.addressToBytes32(), amount, additionalData
            );
            console2.log("Bridge with payload initiated");
        } else {
            // Uses token's configured hook (can be zero => mailbox default hook).
            msgId = token.transferRemote{value: gasPayment}(destination, recipient.addressToBytes32(), amount);
            console2.log("Standard bridge initiated");
        }

        vm.stopBroadcast();

        console2.log("Bridge details:");
        console2.log("To:", recipient);
        console2.log("Destination domain:", destination);
        console2.log("Amount:", amount);
        console2.log("Gas payment:", gasPayment);
        console2.logBytes32(msgId);
    }

    function _createWorkflowData(address workflowExecutor) internal view returns (bytes memory) {
        // Read workflow actions from environment or create example actions
        TokenHypERC20.Action[] memory actions = _getWorkflowActions(workflowExecutor);

        // Encode with workflow identifier
        bytes32 workflowId = keccak256(abi.encodePacked("WORKFLOW"));
        TokenHypERC20.WorkflowData memory workflowData = TokenHypERC20.WorkflowData({actions: actions});
        return abi.encodePacked(workflowId, abi.encode(workflowData));
    }

    function _getWorkflowActions(address workflowExecutor) internal view returns (TokenHypERC20.Action[] memory) {
        // Hardcoded actions payload as requested
        // Action 0: Type 4, Target 0xdAC1B27D40E0971a55D5478e47aDaF2D5E5E8A77
        // Action 1: Type 0, Target 0xed47849Eb9548F164234287964356eF9A6f73075
        // Action 2: Type 1, Target 0xFD5d839EF67bb50a3395f2974419274B47D7cb90

        TokenHypERC20.Action[] memory actions = new TokenHypERC20.Action[](2);

        // Action 0
        actions[0] = TokenHypERC20.Action({
            actionType: 4,
            target: 0xdAC1B27D40E0971a55D5478e47aDaF2D5E5E8A77,
            data: hex"000000000000000000000000dAC1B27D40E0971a55D5478e47aDaF2D5E5E8A77000000000000000000000000000000000000000000000000000000e8d4a51000",
            inputAmountPercentage: 10000
        });

        // Action 1
        // actions[0] = TokenHypERC20.Action({
        //     actionType: 0,
        //     target: 0xed47849Eb9548F164234287964356eF9A6f73075,
        //     data: hex"000000000000000000000000864d3a6f4804abd32d7b42414e33ed1caec5f505000000000000000000000000dAC1B27D40E0971a55D5478e47aDaF2D5E5E8A77000000000000000000000000681db03ef13e37151e9fd68920d2c3427319437900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d49565df5b91ed2fa8cb3f448313cd736ad23c32",
        //     inputAmountPercentage: 10000
        // });

        // Action 2
        actions[1] = TokenHypERC20.Action({
            actionType: 1,
            target: 0xFD5d839EF67bb50a3395f2974419274B47D7cb90,
            data: hex"0000000000000000000000009738885a3946456f471c17f43dd421ebe7ceb0ef000000000000000000000000681db03ef13e37151e9fd68920d2c34273194379000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000",
            inputAmountPercentage: 10000
        });

        console2.log("Created custom workflow actions (3 actions)");
        return actions;
    }

    /// @notice Helper function to update workflow executor
    function updateWorkflowExecutor() external {
        string memory profile = _activeProfile();
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envOr("TOKEN_ADDRESS", _tokenAddressForChain(profile, block.chainid));
        address newExecutor = vm.envAddress("NEW_WORKFLOW_EXECUTOR");

        TokenHypERC20 token = TokenHypERC20(tokenAddr);

        vm.startBroadcast(pk);
        token.setWorkflowExecutor(newExecutor);
        vm.stopBroadcast();

        console2.log("Workflow executor updated to:", newExecutor);
    }
}
