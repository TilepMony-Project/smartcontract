// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface generik untuk setiap adapter bridge.
interface IBridgeAdapter {
    function bridge(
        address token,
        uint256 amount,
        uint256 dstChainId,
        address recipient,
        bytes calldata extraData
    ) external payable;
}
