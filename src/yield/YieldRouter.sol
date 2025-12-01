// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IYieldAdapter} from "./interfaces/IYieldAdapter.sol";

contract YieldRouter {
    error AdapterNotWhitelisted(address adapter);
    error TransferFailed();

    event Deposited(
        address indexed user, address indexed adapter, address indexed token, uint256 amount, uint256 amountOut
    );
    event Withdrawn(
        address indexed user, address indexed adapter, address indexed token, uint256 amount, uint256 amountReceived
    );
    event AdapterWhitelisted(address indexed adapter, bool status);

    mapping(address => bool) public isAdapterWhitelisted;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyWhitelisted(address adapter) {
        if (!isAdapterWhitelisted[adapter]) {
            revert AdapterNotWhitelisted(adapter);
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setAdapterWhitelist(address adapter, bool status) external onlyOwner {
        isAdapterWhitelisted[adapter] = status;
        emit AdapterWhitelisted(adapter, status);
    }

    /**
     * @notice Routes user deposit to the specific adapter.
     * @dev User must approve this contract to spend `token`.
     */
    function deposit(address adapter, address token, uint256 amount, bytes calldata data)
        external
        onlyWhitelisted(adapter)
        returns (uint256)
    {
        // 1. Transfer tokens from user to this router
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        // 2. Approve adapter to spend tokens
        IERC20(token).approve(adapter, amount);

        // 3. Call adapter deposit
        uint256 amountOut = IYieldAdapter(adapter).deposit(token, amount, data);

        // 4. Transfer receipt tokens (if any) back to user
        // Note: Some protocols might mint directly to the msg.sender (this contract),
        // so we need to check if the adapter returns receipt tokens to this contract and forward them.
        // For simplicity in this router, we assume the adapter handles the logic or returns the amount.
        // If the adapter mints tokens to `address(this)`, we should forward them.
        // Implementation detail: The adapter should ideally mint to the `msg.sender` of the `deposit` call (this router),
        // and then this router forwards to the user. Or the adapter takes a `recipient` param.
        // For now, let's assume the adapter returns the amount of receipt tokens it minted to this router.

        // TODO: Handle receipt token forwarding if the protocol issues LP tokens.
        // For now, we just emit the event.

        emit Deposited(msg.sender, adapter, token, amount, amountOut);
        return amountOut;
    }

    /**
     * @notice Routes user withdrawal from the specific adapter.
     */
    function withdraw(address adapter, address token, uint256 amount, bytes calldata data)
        external
        onlyWhitelisted(adapter)
        returns (uint256)
    {
        // 1. User must transfer their LP/Receipt tokens to this router first (if applicable),
        // OR approve this router to burn/spend them.
        // This flow depends heavily on whether the user holds an LP token or if the position is tracked internally.

        // Assuming user holds an LP token and approves this router:
        // IERC20(lpToken).transferFrom(msg.sender, address(this), amount);

        // For this generic implementation, we assume the `amount` refers to the underlying asset amount
        // or the share amount, and the adapter handles the logic.

        // Call adapter withdraw
        uint256 amountReceived = IYieldAdapter(adapter).withdraw(token, amount, data);

        // Transfer underlying back to user
        bool success = IERC20(token).transfer(msg.sender, amountReceived);
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, adapter, token, amount, amountReceived);
        return amountReceived;
    }
}
