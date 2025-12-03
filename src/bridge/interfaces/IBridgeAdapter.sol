// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IBridgeAdapter {
    struct BridgeParams {
        address token;
        uint256 amount;
        string destinationChain;
        address destinationAddress;
        address receiver;
        bytes extraData;
    }

    /**
     * @notice Initiates a bridge request through a specific router/provider.
     * @param params   Payload that describes the bridging intent.
     * @param from     Address that currently holds the tokens. When integrating
     *                 with an aggregator contract this will usually be the aggregator
     *                 itself, otherwise end users can pass address(0) to default to msg.sender.
     * @return bridgeId Unique identifier emitted by the router that adapters can use
     *                  for accounting and tracking.
     */
    function bridge(BridgeParams calldata params, address from) external payable returns (bytes32 bridgeId);
}
