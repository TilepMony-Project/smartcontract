// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title MockTokenHypERC20
/// @notice Lightweight stand-in for TokenHypERC20 used in tests.
/// @dev Captures payload data and emulates workflow execution without the Hyperlane dependency.
contract MockTokenHypERC20 is ERC20, Ownable {
    struct Action {
        uint8 actionType;
        address target;
        bytes data;
        uint256 inputAmountPercentage;
    }

    struct WorkflowData {
        Action[] actions;
    }

    event WorkflowCallResult(bool callSuccess, bytes returnData);

    event AdditionalDataSent(
        bytes32 indexed messageId, uint32 indexed destination, bytes32 indexed recipient, bytes data
    );

    event AdditionalDataReceived(uint32 indexed origin, bytes32 indexed recipient, bytes data);

    event WorkflowExecuted(
        bytes32 indexed messageId, address indexed workflowExecutor, uint256 indexed amount, bool success
    );

    event WorkflowExecutorUpdated(address indexed oldExecutor, address indexed newExecutor);

    bytes32 public constant WORKFLOW_ID = keccak256("WORKFLOW");

    address public workflowExecutor;

    uint32 public lastOutboundDestination;
    bytes32 public lastOutboundRecipient;
    uint256 public lastOutboundAmount;
    uint256 public lastOutboundValue;
    bytes32 public lastOutboundMessageId;
    bytes public lastOutboundMetadata;

    uint32 public lastInboundOrigin;
    bytes32 public lastInboundSender;
    bytes32 public lastInboundRecipient;
    uint256 public lastInboundAmount;
    bytes public lastInboundMetadata;

    bool public lastWorkflowSuccess;
    bytes public lastWorkflowReturnData;

    Action[] private _lastWorkflowActions;

    constructor(string memory name_, string memory symbol_, address _workflowExecutor)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        workflowExecutor = _workflowExecutor;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setWorkflowExecutor(address _workflowExecutor) external onlyOwner {
        address oldExecutor = workflowExecutor;
        workflowExecutor = _workflowExecutor;
        emit WorkflowExecutorUpdated(oldExecutor, _workflowExecutor);
    }

    function giveMe(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function transferRemoteWithPayload(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _additionalData
    ) external payable returns (bytes32 messageId) {
        require(_amount > 0, "MockTokenHypERC20: amount zero");

        _burn(msg.sender, _amount);

        messageId = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, _destination, _recipient, _amount, _additionalData)
        );

        lastOutboundDestination = _destination;
        lastOutboundRecipient = _recipient;
        lastOutboundAmount = _amount;
        lastOutboundValue = msg.value;
        lastOutboundMessageId = messageId;
        lastOutboundMetadata = _additionalData;

        if (_additionalData.length > 0) {
            emit AdditionalDataSent(messageId, _destination, _recipient, _additionalData);
        }
    }

    function simulateHandle(
        uint32 _origin,
        bytes32 _sender,
        address _recipient,
        uint256 _amount,
        bytes calldata _metadata
    ) external {
        require(_recipient != address(0), "MockTokenHypERC20: recipient zero");

        lastInboundOrigin = _origin;
        lastInboundSender = _sender;
        lastInboundRecipient = _addressToBytes32(_recipient);
        lastInboundAmount = _amount;
        lastInboundMetadata = _metadata;

        _mint(_recipient, _amount);

        if (_metadata.length > 0) {
            emit AdditionalDataReceived(_origin, lastInboundRecipient, _metadata);
            _maybeExecuteWorkflow(_metadata);
        }
    }

    function encodeWorkflowData(Action[] calldata _actions) external pure returns (bytes memory) {
        Action[] memory actionsCopy = _copyActions(_actions);
        WorkflowData memory workflowData = WorkflowData({actions: actionsCopy});
        return abi.encodePacked(WORKFLOW_ID, abi.encode(workflowData));
    }

    function getLastWorkflowActions() external view returns (Action[] memory) {
        Action[] memory copy = new Action[](_lastWorkflowActions.length);
        for (uint256 i = 0; i < copy.length; i++) {
            copy[i] = _lastWorkflowActions[i];
        }
        return copy;
    }

    function _maybeExecuteWorkflow(bytes calldata _metadata) internal {
        if (workflowExecutor == address(0) || _metadata.length < 32) {
            return;
        }

        bytes32 metadataId;
        assembly {
            metadataId := calldataload(_metadata.offset)
        }

        if (metadataId != WORKFLOW_ID) {
            return;
        }

        bytes calldata workflowPayload = _metadata[32:];
        WorkflowData memory workflowData = abi.decode(workflowPayload, (WorkflowData));

        delete _lastWorkflowActions;
        for (uint256 i = 0; i < workflowData.actions.length; i++) {
            _lastWorkflowActions.push(workflowData.actions[i]);
        }

        uint256 available = balanceOf(address(this));
        _approve(address(this), workflowExecutor, available);

        (bool success, bytes memory returnData) = workflowExecutor.call(
            abi.encodeWithSignature(
                "executeWorkflow((uint8,address,bytes,uint256)[],address,uint256)",
                workflowData.actions,
                address(this),
                available
            )
        );

        lastWorkflowSuccess = success;
        lastWorkflowReturnData = returnData;

        emit WorkflowCallResult(success, returnData);

        bytes32 messageId = keccak256(abi.encodePacked(block.timestamp, workflowPayload));
        emit WorkflowExecuted(messageId, workflowExecutor, available, success);
    }

    function _copyActions(Action[] calldata _actions) private pure returns (Action[] memory) {
        Action[] memory copy = new Action[](_actions.length);
        for (uint256 i = 0; i < _actions.length; i++) {
            copy[i] = _actions[i];
        }
        return copy;
    }

    function _addressToBytes32(address account) private pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }
}
