// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IBridgeRouter {
    event BridgeInitiated(
        bytes32 indexed bridgeId,
        address indexed caller,
        address indexed receiver,
        address token,
        uint256 amount,
        string destinationChain,
        address destinationContract,
        bytes extraData
    );

    event BridgeCompleted(bytes32 indexed bridgeId, address indexed token, address indexed receiver, uint256 amount);

    event SupportedTokenUpdated(address indexed token, bool status);

    /**
     * @dev Bridge tokens to another chain. Implementations are expected to pull the tokens
     *      from `msg.sender`, therefore the caller must approve the router beforehand.
     */
    function bridgeToken(
        address token,
        uint256 amount,
        string calldata destinationChain,
        address destinationContract,
        address receiver,
        bytes calldata extraData
    ) external payable returns (bytes32 bridgeId);

    /**
     * @dev Helper for frontends/adapters to know how much native token fee should be
     *      forwarded as msg.value when calling {bridgeToken}.
     */
    function quoteFee(string calldata destinationChain, uint256 amount, bytes calldata extraData)
        external
        view
        returns (uint256);

    /**
     * @dev Releases the bridged assets on the destination chain once the cross-chain
     *      messaging layer confirms the transfer. Implementations are expected to apply
     *      their own access control (e.g. onlyOwner or proof-based validation).
     */
    function completeBridge(address token, address receiver, uint256 amount, bytes32 bridgeId) external;
}
