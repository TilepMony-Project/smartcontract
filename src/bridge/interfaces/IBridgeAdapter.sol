// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBridgeAdapter {
    function bridge(
        address token,
        uint32 destination,
        bytes32 recipient,
        uint256 amount,
        bytes calldata data
    ) external payable;
}
