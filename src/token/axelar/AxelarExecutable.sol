// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAxelarGateway} from "./IAxelarGateway.sol";

/// @title Minimal AxelarExecutable-style base contract
/// @notice In real Axelar deployments, execute() can only be called by the Axelar Gateway.
///         Here we simulate that behavior with MockGateway in the tests.
abstract contract AxelarExecutable {
    error NotApprovedByGateway();

    IAxelarGateway public gateway;

    function _setGateway(address gateway_) internal {
        require(gateway_ != address(0), "AxelarExecutable: zero gateway");
        gateway = IAxelarGateway(gateway_);
    }

    /// @notice Called by the Gateway whenever a cross-chain message arrives.
    function execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external virtual {
        // require(msg.sender == address(gateway), "AxelarExecutable: only gateway"kal);
        bytes32 payloadHash = keccak256(payload);
        if (!gateway.validateContractCall(commandId, sourceChain, sourceAddress, payloadHash))
            revert NotApprovedByGateway();
        _execute(commandId, sourceChain, sourceAddress, payload);
    }

    function _execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal virtual;
}
