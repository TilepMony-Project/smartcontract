// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {TokenHypERC20} from "../../token/TokenHypERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract HypERC20Adapter is IBridgeAdapter {
    using SafeERC20 for IERC20;
    /**
     * @notice Bridge tokens using Hyperlane TokenHypERC20
     * @param token The TokenHypERC20 to bridge
     * @param destination The destination chain ID
     * @param recipient The recipient address on the destination chain
     * @param amount The amount of tokens to bridge
     * @param data Additional data (payload) for the bridge transfer
     */
    function bridge(
        address token,
        uint32 destination,
        bytes32 recipient,
        uint256 amount,
        bytes calldata data
    ) external payable override {
        // Transfer tokens from sender (BridgeRouter or MainController) to this adapter
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate remote transfer fee if applicable (Hyperlane usually handles this via IGP)
        // For TokenHypERC20, we can use the payable transferRemoteWithPayload

        // Execute bridge transfer
        // Note: msg.value is passed along for gas payment
        TokenHypERC20(token).transferRemoteWithPayload{value: msg.value}(
            destination,
            recipient,
            amount,
            data
        );
    }
}
