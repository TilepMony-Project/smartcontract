// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "./interfaces/IBridgeAdapter.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract BridgeRouter is IBridgeRouter, Ownable {
    using SafeERC20 for IERC20;

    // Mapping from token address to bridge adapter address
    mapping(address => address) public adapters;

    event AdapterSet(address indexed token, address indexed adapter);
    event BridgeExecuted(
        address indexed token,
        address indexed adapter,
        uint32 destination,
        uint256 amount
    );

    constructor(address _owner) Ownable() {
        _transferOwnership(_owner);
    }

    /**
     * @notice Set or update the adapter for a specific token
     * @param token The token address
     * @param adapter The adapter address
     */
    function setAdapter(address token, address adapter) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(adapter != address(0), "Invalid adapter address");
        adapters[token] = adapter;
        emit AdapterSet(token, adapter);
    }

    /**
     * @notice Bridge tokens using the registered adapter
     * @param _tokenAddress The token to bridge
     * @param _destination The destination chain ID
     * @param _recipient The recipient address on the destination chain
     * @param _amount The amount of tokens to bridge
     * @param _additionalData Additional data for the bridge action
     */
    function bridge(
        address _tokenAddress,
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _additionalData
    ) external payable override {
        address adapter = adapters[_tokenAddress];
        require(adapter != address(0), "Adapter not found for token");

        // Transfer tokens from sender (MainController) to this router
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // Approve adapter to spend tokens
        IERC20(_tokenAddress).forceApprove(adapter, _amount);

        // execute bridge on adapter
        IBridgeAdapter(adapter).bridge{value: msg.value}(
            _tokenAddress,
            _destination,
            _recipient,
            _amount,
            _additionalData
        );

        emit BridgeExecuted(_tokenAddress, adapter, _destination, _amount);
    }
}
