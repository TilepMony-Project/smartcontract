// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBridgeAdapter} from "./adapters/IBridgeAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Abstraction bridge layer: memilih adapter (saat ini hanya Axelar).
contract BridgeLayer is Ownable {
    address public axelarAdapter;

    event AdapterUpdated(address adapter);
    event BridgeRequested(address token, uint256 amount, uint256 dstChainId, address recipient);

    constructor() Ownable(msg.sender) {}

    function setAxelarAdapter(address adapter) external onlyOwner {
        axelarAdapter = adapter;
        emit AdapterUpdated(adapter);
    }

    function bridge(address token, uint256 amount, uint256 dstChainId, address recipient, bytes calldata extraData)
        external
        payable
    {
        require(axelarAdapter != address(0), "BridgeLayer: NO_ADAPTER");

        emit BridgeRequested(token, amount, dstChainId, recipient);

        IBridgeAdapter(axelarAdapter).bridge{value: msg.value}(token, amount, dstChainId, recipient, extraData);
    }
}
