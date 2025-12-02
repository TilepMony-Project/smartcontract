// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Minimal Axelar Gas Service interface for local testing
interface IAxelarGasService {
    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable;
}
