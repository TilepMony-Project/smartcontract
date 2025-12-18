// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Common.sol";
import "./TokenProfileScript.sol";
import {TokenHypERC20} from "../../src/token/TokenHypERC20.sol";

// Mock Workflow Executor untuk deployment
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

    // Fallback untuk menerima ETH
    receive() external payable {}
}

/// @notice Deploy TokenHypERC20 deterministically using EIP-2470.
contract DeployTokenHypERC20 is TokenProfileScript {
    address constant EIP2470_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

    struct TokenConfig {
        uint8 decimals;
        uint256 scale;
        string name;
        string symbol;
        address hook;
        address ism;
        uint256 initialSupply;
    }

    function _initCode(address mailbox, address owner_, address workflowExecutor, TokenConfig memory cfg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            type(TokenHypERC20).creationCode,
            abi.encode(
                mailbox,
                cfg.decimals,
                cfg.scale,
                cfg.name,
                cfg.symbol,
                cfg.hook,
                cfg.ism,
                owner_,
                cfg.initialSupply,
                workflowExecutor
            )
        );
    }

    function _predict(bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), EIP2470_FACTORY, salt, initCodeHash)))));
    }

    function run() external {
        string memory profile = _activeProfile();
        console2.log("Using token profile:", profile);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        // Default salt string if not provided
        string memory saltString = vm.envOr("SALT_STRING", string("HYPERLANE_WORKFLOW_TOKEN"));
        bytes32 salt = keccak256(bytes(saltString));
        address mailbox = vm.envAddress("MAILBOX");

        address workflowExecutor = _profileAddress(
            profile,
            "WORKFLOW_EXECUTOR",
            "WORKFLOW_EXECUTOR",
            address(0)
        );

        // Token configuration
        TokenConfig memory cfg = TokenConfig({
            decimals: uint8(_profileUint(profile, "DECIMALS", "TOKEN_DECIMALS", 18)),
            scale: _profileUint(profile, "SCALE", "TOKEN_SCALE", 1 ether),
            name: _profileString(profile, "NAME", "TOKEN_NAME", "Workflow Token"),
            symbol: _profileString(profile, "SYMBOL", "TOKEN_SYMBOL", "WFT"),
            hook: _profileAddress(profile, "HOOK", "HOOK", address(0)),
            ism: _profileAddress(profile, "ISM", "ISM", address(0)),
            initialSupply: _profileUint(profile, "TOTAL_SUPPLY", "TOTAL_SUPPLY", 1_000_000 ether)
        });

        vm.startBroadcast(pk);

        // If no workflow executor provided, deploy a mock one
        if (workflowExecutor == address(0)) {
            console2.log("Deploying mock workflow executor...");
            MockWorkflowExecutor mockExecutor = new MockWorkflowExecutor();
            workflowExecutor = address(mockExecutor);
            console2.log("Mock executor deployed to:", workflowExecutor);
        }

        bytes memory initCode = _initCode(mailbox, deployer, workflowExecutor, cfg);
        bytes32 initCodeHash = keccak256(initCode);
        address predicted = _predict(salt, initCodeHash);

        console2.log("EIP-2470 factory:", EIP2470_FACTORY);
        console2.log("Mailbox:", mailbox);
        console2.log("Workflow Executor:", workflowExecutor);
        console2.logBytes32(salt);
        console2.log("Predicted token address:", predicted);

        // Deploy via singleton factory
        address deployed = ISingletonFactory(EIP2470_FACTORY).deploy(initCode, salt);

        if (deployed == address(0)) {
            console2.log("Token already deployed (or deployment failed). Using predicted:", predicted);
            deployed = predicted;
        } else {
            console2.log("Token deployed successfully via factory:", deployed);
        }

        vm.stopBroadcast();

        TokenHypERC20 token = TokenHypERC20(deployed);
        address tokenAddr = address(token);

        console2.log("Token Address:", tokenAddr);
        console2.log("Workflow Executor:", token.getWorkflowExecutor());

        _logProfileEnvHints(profile, tokenAddr, workflowExecutor);
    }

    /// @notice Deploy mock workflow executor for testing
    function deployMockWorkflowExecutor() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        MockWorkflowExecutor mockExecutor = new MockWorkflowExecutor();
        vm.stopBroadcast();

        console2.log("Mock workflow executor deployed to:", address(mockExecutor));
        console2.log("Add to .env: WORKFLOW_EXECUTOR=", address(mockExecutor));
    }

    /// @notice Update workflow executor for existing token
    function updateWorkflowExecutor() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address newExecutor = vm.envAddress("NEW_WORKFLOW_EXECUTOR");

        TokenHypERC20 token = TokenHypERC20(tokenAddr);

        vm.startBroadcast(pk);
        token.setWorkflowExecutor(newExecutor);
        vm.stopBroadcast();

        console2.log("Workflow executor updated!");
        console2.log("Token:", tokenAddr);
        console2.log("New Executor:", newExecutor);
    }

    function checkWorkflowExecutor() external view {
        string memory profile = _activeProfile();
        address tokenAddr = vm.envOr("TOKEN_ADDRESS", _tokenAddressForChain(profile, block.chainid));
        TokenHypERC20 token = TokenHypERC20(tokenAddr);
        console2.log("Token:", tokenAddr);
        console2.log("Current Executor:", token.getWorkflowExecutor());
    }

    function _chainLabel(uint256 chainId) internal view returns (string memory) {
        if (chainId == vm.envUint("BASE_SEPOLIA_DOMAIN")) {
            return "BASE";
        }
        if (chainId == vm.envUint("MANTLE_SEPOLIA_DOMAIN")) {
            return "MANTLE";
        }
        return vm.toString(chainId);
    }

    function _logProfileEnvHints(string memory profile, address tokenAddr, address workflowExecutor) internal view {
        console2.log("");
        console2.log("Environment variables to update:");

        string memory chainLabel = _chainLabel(block.chainid);
        string memory tokenEnvKey = string.concat("TOKEN_ADDRESS_", chainLabel, "_", profile);
        console2.log(tokenEnvKey, tokenAddr);

        string memory executorEnvKey = _profileKey(profile, "WORKFLOW_EXECUTOR");
        console2.log(executorEnvKey, workflowExecutor);
    }
}
