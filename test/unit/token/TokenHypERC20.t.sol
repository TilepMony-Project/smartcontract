// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TokenHypERC20} from "../../../src/token/TokenHypERC20.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";
import {Message} from "@hyperlane-xyz/core/token/libs/Message.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";
import {IInterchainGasPaymaster} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainGasPaymaster.sol";

contract MockMailbox is IMailbox {
    uint32 public domain;
    uint32 public messageCount;
    bytes32 public rootValue;
    bytes32 public latestCheckpointRoot;
    uint32 public latestCheckpointIndex;

    constructor(uint32 _domain) {
        domain = _domain;
    }

    function localDomain() external view returns (uint32) {
        return domain;
    }

    function delivered(bytes32) external pure returns (bool) {
        return false;
    }

    function defaultIsm() external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    function latestDispatchedId() external pure returns (bytes32) {
        return bytes32(0);
    }

    function nonce() external pure returns (uint32) {
        return 0;
    }

    function dispatch(uint32, bytes32, bytes calldata) external returns (bytes32) {
        messageCount += 1;
        return bytes32(uint256(messageCount));
    }

    function process(bytes calldata, bytes calldata) external {}

    function count() external view returns (uint32) {
        return messageCount;
    }

    function root() external view returns (bytes32) {
        return rootValue;
    }

    function latestCheckpoint() external view returns (bytes32, uint32) {
        return (latestCheckpointRoot, latestCheckpointIndex);
    }

    function recipientIsm(address) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
}

contract MockInterchainGasPaymaster is IInterchainGasPaymaster {
    function payForGas(
        bytes32 _messageId,
        uint32,
        uint256 _gasAmount,
        address
    ) external payable {
        emit GasPayment(_messageId, _gasAmount, msg.value);
    }

    function quoteGasPayment(uint32, uint256) external pure returns (uint256) {
        return 0;
    }
}

// Simple Mock Workflow Executor for testing
contract MockWorkflowExecutor {
    event WorkflowExecuted(
        address indexed caller, address indexed recipient, uint256 indexed amount, uint256 actionCount
    );

    struct Action {
        address target;
        bytes4 selector;
        bytes data;
        uint256 value;
    }

    bool public shouldFail = false;
    uint256 public executionCount = 0;

    function executeWorkflow(Action[] calldata actions, address initialToken, uint256 initialAmount) external payable {
        if (shouldFail) {
            revert("Mock workflow execution failed");
        }

        executionCount++;
        emit WorkflowExecuted(msg.sender, initialToken, initialAmount, actions.length);

        // Simple mock execution - just validate inputs
        require(actions.length > 0, "No actions provided");
        require(initialToken != address(0), "Invalid recipient");
        require(initialAmount > 0, "Invalid amount");
    }

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function getExecutionCount() external view returns (uint256) {
        return executionCount;
    }

    receive() external payable {}
}

contract TokenHypERC20Test is Test {
    using TypeCasts for address;

    uint256 constant INITIAL_SUPPLY = 1000 ether;

    MockWorkflowExecutor workflowExecutor;
    TokenHypERC20 token;
    MockMailbox mockMailbox;
    MockInterchainGasPaymaster mockIGP;

    address owner = address(0x1);
    address recipient = address(0x2);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock workflow executor
        workflowExecutor = new MockWorkflowExecutor();

        // Deploy mock dependencies
        mockMailbox = new MockMailbox(1);
        mockIGP = new MockInterchainGasPaymaster();

        // Deploy the workflow token
        token = new TokenHypERC20(
            address(mockMailbox),
            18,
            "Workflow Token",
            "WFT",
            address(mockIGP),
            address(0), // No interchain security module
            owner,
            INITIAL_SUPPLY,
            address(workflowExecutor)
        );

        vm.stopPrank();
    }

    function test_ownerIsSet() public {
        assertEq(token.owner(), owner);
    }

    function test_enrollRemoteRouter() public {
        vm.prank(owner);
        uint32 remoteDomain = 421614;
        address remoteRouter = address(0xCAFE);

        token.enrollRemoteRouter(remoteDomain, remoteRouter.addressToBytes32());

        // Router stores bytes32 routers; for EVM it's the address bytes32.
        assertEq(token.routers(remoteDomain), remoteRouter.addressToBytes32());
    }

    function test_onlyOwnerCanEnroll() public {
        uint32 remoteDomain = 11155420;
        address remoteRouter = address(0xDEAD);

        vm.expectRevert();
        token.enrollRemoteRouter(remoteDomain, remoteRouter.addressToBytes32());
    }

    function test_transferRemoteWithPayloadEmitsEvent() public {
        uint32 destination = 421_614;
        bytes32 remoteRouter = address(0xBEEF).addressToBytes32();
        vm.prank(owner);
        token.enrollRemoteRouter(destination, remoteRouter);

        bytes32 testRecipient = address(0xCAFE).addressToBytes32();
        bytes memory payload = bytes("memo");

        vm.startPrank(owner);
        // messageId comes from mocked mailbox dispatch; only match the remaining indexed topics
        vm.expectEmit(false, true, true, true, address(token));
        emit TokenHypERC20.AdditionalDataSent(bytes32(0), destination, testRecipient, payload);
        token.transferRemoteWithPayload(destination, testRecipient, 1e18, payload);
        vm.stopPrank();
    }

    function test_handleEmitsAdditionalDataReceived() public {
        uint32 origin = 84532;
        bytes32 remoteRouter = address(0xBEEF).addressToBytes32();
        vm.prank(owner);
        token.enrollRemoteRouter(origin, remoteRouter);

        bytes32 testRecipient = address(0xCAFE).addressToBytes32();
        bytes memory payload = bytes("meta");
        bytes memory message = Message.format(testRecipient, 1e18, payload);

        vm.expectEmit(true, true, false, true, address(token));
        emit TokenHypERC20.AdditionalDataReceived(origin, testRecipient, payload);

        vm.prank(address(token.mailbox()));
        token.handle(origin, remoteRouter, message);
    }
}
