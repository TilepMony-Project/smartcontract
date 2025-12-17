// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IYieldAdapter} from "./interfaces/IYieldAdapter.sol";

contract YieldRouter is Ownable {
    using SafeERC20 for IERC20;

    error AdapterNotWhitelisted(address adapter);

    event Deposited(
        address indexed user, address indexed adapter, address indexed token, uint256 amount, uint256 amountOut
    );
    event Withdrawn(
        address indexed user, address indexed adapter, address indexed token, uint256 amount, uint256 amountReceived
    );
    event AdapterWhitelisted(address indexed adapter, bool status);

    mapping(address => bool) public isAdapterWhitelisted;

    constructor() Ownable(msg.sender) {}

    modifier onlyWhitelisted(address adapter) {
        _onlyWhitelisted(adapter);
        _;
    }

    function _onlyWhitelisted(address adapter) internal view {
        if (!isAdapterWhitelisted[adapter]) {
            revert AdapterNotWhitelisted(adapter);
        }
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
        returns (uint256, address)
    {
        // 1. Transfer tokens from user to this router
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Approve adapter to spend tokens
        // forceApprove ensures compatibility even if approval isn't 0 first
        IERC20(token).forceApprove(adapter, amount);

        // 3. Call adapter deposit
        (uint256 amountOut, address shareToken) = IYieldAdapter(adapter).deposit(token, amount, data);

        // 4. Transfer receipt tokens (shares) back to user
        // NOTE: We do NOT transfer back to user automatically anymore if the MainController
        // is the caller, because MainController wants to hold it for the next action.
        // BUT, YieldRouter is designed to be used by EOAs too.
        // The original issue was MainController *holding* it but not knowing *what* it held.
        // If we want to support dynamic transfer, MainController should keep it.
        // IF we transfer it here, MainController receives it.

        // Wait, if MainController calls this, MainController IS msg.sender.
        // So this transfer sends it to MainController.
        if (shareToken != address(0) && amountOut > 0) {
            IERC20(shareToken).safeTransfer(msg.sender, amountOut);
        }

        emit Deposited(msg.sender, adapter, token, amount, amountOut);
        return (amountOut, shareToken);
    }

    /**
     * @notice Routes user withdrawal from the specific adapter.
     */
    function withdraw(
        address adapter,
        address shareToken, // Explicitly passed share token
        address token, // Underlying token
        uint256 amount, // Share amount
        bytes calldata data
    )
        external
        onlyWhitelisted(adapter)
        returns (uint256)
    {
        // 1. Pull shares from User
        IERC20(shareToken).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Transfer shares to Adapter (so it can burn them)
        IERC20(shareToken).safeTransfer(adapter, amount);

        // 3. Call adapter withdraw
        // Note: 'amount' passed to adapter is typically the share amount to burn
        // The adapter should handle burning the shares from 'this' (Router)
        uint256 amountReceived = IYieldAdapter(adapter).withdraw(token, amount, data);

        // 4. Transfer underlying back to user
        IERC20(token).safeTransfer(msg.sender, amountReceived);

        emit Withdrawn(msg.sender, adapter, token, amount, amountReceived);
        return amountReceived;
    }
}
