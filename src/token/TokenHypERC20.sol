// SPDX-License-Identifier: MIT
// Enhanced version with workflow support
pragma solidity ^0.8.20;

import {HypERC20} from "@hyperlane-xyz/core/token/HypERC20.sol";
import {Message} from "@hyperlane-xyz/core/token/libs/Message.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

/// @title TokenHypERC20
/// @notice Enhanced Hyperlane Synthetic ERC20 with workflow execution capability
/// @dev This contract can execute external workflows when receiving additional data
contract TokenHypERC20 is HypERC20 {
    using TypeCasts for address;

    event WorkflowCallResult(bool callSuccess, bytes returnData);

    event AdditionalDataSent(
        bytes32 indexed messageId, uint32 indexed destination, bytes32 indexed recipient, bytes data
    );

    event AdditionalDataReceived(uint32 indexed origin, bytes32 indexed recipient, bytes data);

    event WorkflowExecuted(
        bytes32 indexed messageId, address indexed workflowExecutor, uint256 indexed amount, bool success
    );

    event WorkflowExecutorUpdated(address indexed oldExecutor, address indexed newExecutor);

    // Struct untuk Action dalam workflow (Updated to match user payload)
    struct Action {
        uint8 actionType;
        address target; // targetContract
        bytes data;
        uint256 inputAmountPercentage;
    }

    // Struct untuk Workflow Data
    struct WorkflowData {
        Action[] actions; // Array of actions to execute
    }

    // Address dari contract yang bisa diubah-ubah untuk executeWorkflow
    address public workflowExecutor;

    constructor(
        address mailbox,
        uint8 decimals_,
        string memory name_,
        string memory symbol_,
        address interchainGasPaymaster_,
        address interchainSecurityModule_,
        address owner_,
        uint256 initialSupply_,
        address _workflowExecutor
    ) HypERC20(decimals_) {
        workflowExecutor = _workflowExecutor;
        _demoInit(mailbox, interchainGasPaymaster_, interchainSecurityModule_, owner_, name_, symbol_, initialSupply_);
    }

    function _demoInit(
        address mailbox_,
        address interchainGasPaymaster_,
        address interchainSecurityModule_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) internal initializer {
        if (interchainGasPaymaster_ == address(0)) {
            __HyperlaneConnectionClient_initialize(mailbox_);
            if (interchainSecurityModule_ != address(0)) {
                _setInterchainSecurityModule(interchainSecurityModule_);
            }
            _transferOwnership(owner_);
        } else {
            __HyperlaneConnectionClient_initialize(mailbox_, interchainGasPaymaster_, interchainSecurityModule_, owner_);
        }
        __ERC20_init(name_, symbol_);
        _mint(owner_, initialSupply_);
    }

    function _calculateFeesAndCharge(uint32, bytes32, uint256 _amount, uint256 nativeValue)
        internal
        returns (bytes memory, uint256)
    {
        bytes memory metadata = _transferFromSender(_amount);
        return (metadata, nativeValue);
    }

    function _outboundAmount(uint256 _amount) internal pure returns (uint256) {
        return _amount;
    }

    function _emitAndDispatch(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        uint256 gasPayment,
        bytes memory outboundMessage
    ) internal returns (bytes32) {
        bytes32 messageId;
        if (address(interchainGasPaymaster) == address(0)) {
            require(gasPayment == 0, "IGP not configured");
            messageId = _dispatch(_destination, outboundMessage);
        } else {
            messageId = _dispatchWithGas(_destination, outboundMessage, gasPayment, msg.sender);
        }
        emit SentTransferRemote(_destination, _recipient, _amount);
        return messageId;
    }

    /**
     * @notice Update workflow executor address
     * @dev Only callable by owner
     */
    function setWorkflowExecutor(address _workflowExecutor) external onlyOwner {
        address oldExecutor = workflowExecutor;
        workflowExecutor = _workflowExecutor;
        emit WorkflowExecutorUpdated(oldExecutor, _workflowExecutor);
    }

    /**
     * @notice transferRemote with workflow execution capability
     * @dev Additional data can contain workflow parameters
     */
    function transferRemoteWithPayload(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _additionalData
    ) external payable returns (bytes32 messageId) {
        (, uint256 remainingNativeValue) = _calculateFeesAndCharge(_destination, _recipient, _amount, msg.value);

        uint256 scaledAmount = _outboundAmount(_amount);
        bytes memory outboundMessage = Message.format(_recipient, scaledAmount, _additionalData);

        messageId = _emitAndDispatch(_destination, _recipient, scaledAmount, remainingNativeValue, outboundMessage);

        if (_additionalData.length > 0) {
            emit AdditionalDataSent(messageId, _destination, _recipient, _additionalData);
        }
    }

    function _handle(uint32 _origin, bytes32 _sender, bytes calldata _message) internal override {
        bytes calldata metadata = Message.metadata(_message);

        // Mint tokens first (from parent HypERC20)
        super._handle(_origin, _sender, _message);

        if (metadata.length > 0) {
            emit AdditionalDataReceived(_origin, Message.recipient(_message), metadata);

            // Try to execute workflow if metadata contains workflow data
            _tryExecuteWorkflow(_origin, _sender, _message, metadata);
        }
    }

    /**
     * @notice Try to execute workflow from additional data
     * @dev Uses try-catch to prevent workflow failure from breaking token mint
     */
    function _tryExecuteWorkflow(uint32 _origin, bytes32 _sender, bytes calldata _message, bytes calldata _metadata)
        internal
    {
        if (workflowExecutor == address(0)) {
            return; // No workflow executor set
        }

        // Check if metadata starts with workflow identifier
        // Format: keccak256("WORKFLOW") + encoded WorkflowData
        bytes32 workflowId = keccak256(abi.encodePacked("WORKFLOW"));

        if (_metadata.length < 32) {
            return; // Too short for workflow identifier
        }

        bytes32 metadataId = bytes32(_metadata[:32]);
        if (metadataId != workflowId) {
            return; // Not a workflow data
        }

        bytes calldata workflowDataBytes = _metadata[32:];

        try this._executeWorkflowSafely(workflowDataBytes, Message.recipient(_message), Message.amount(_message)) {
        // Workflow executed successfully
        }
            catch {
            // Workflow failed but tokens are already minted
            // Emit failure event if needed
        }
    }

    /**
     * @notice Execute workflow safely with external call
     */
    function _executeWorkflowSafely(bytes calldata _workflowDataBytes, bytes32 _recipient, uint256 _amount) external {
        require(msg.sender == address(this), "Only internal call");

        try this._decodeAndExecute(_workflowDataBytes, _recipient, _amount) returns (bool success) {
            // Generate mock messageId for event (using hash of workflow data)
            bytes32 messageId = keccak256(abi.encodePacked(block.timestamp, _workflowDataBytes));

            emit WorkflowExecuted(messageId, workflowExecutor, _amount, success);
        } catch {
            bytes32 messageId = keccak256(abi.encodePacked(block.timestamp, _workflowDataBytes));
            emit WorkflowExecuted(messageId, workflowExecutor, _amount, false);
        }
    }

    /**
     * @notice Decode workflow data and execute external contract
     */
    function _decodeAndExecute(
        bytes calldata _workflowDataBytes,
        bytes32 _recipient,
        uint256 /*_amount*/
    )
        external
        returns (bool success)
    {
        require(msg.sender == address(this), "Only internal call");

        WorkflowData memory workflowData = abi.decode(_workflowDataBytes, (WorkflowData));

        // Karena kamu akan set recipient = token contract sendiri,
        // token hasil mint ada di address(this).
        uint256 available = balanceOf(address(this));

        // approve main controller supaya dia bisa pull token dari token contract
        _approve(address(this), workflowExecutor, available);

        (bool callSuccess, bytes memory ret) = workflowExecutor.call(
            abi.encodeWithSignature(
                "executeWorkflow((uint8,address,bytes,uint256)[],address,uint256)",
                workflowData.actions,
                address(this),
                available
            )
        );

        emit WorkflowCallResult(callSuccess, ret);
        return callSuccess;
    }

    /**
     * @notice Utility function to encode workflow data for transfer
     * @dev Use this function to create additional data for bridge with workflow
     */
    function encodeWorkflowData(Action[] calldata _actions) external view returns (bytes memory) {
        WorkflowData memory workflowData = WorkflowData({actions: _actions});

        bytes32 workflowId = keccak256(abi.encodePacked("WORKFLOW"));
        return abi.encodePacked(workflowId, abi.encode(workflowData));
    }

    /**
     * @notice Get current workflow executor address
     */
    function getWorkflowExecutor() external view returns (address) {
        return workflowExecutor;
    }

    /**
     * @notice Validate workflow executor exists
     */
    function _isValidWorkflowExecutor() internal view returns (bool) {
        return workflowExecutor != address(0);
    }

    /**
     * @notice Faucet-style mint for workflow MINT action
     */
    function giveMe(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
