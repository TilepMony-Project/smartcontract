// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IYieldAdapter {
    struct ProtocolInfo {
        string name;
        string description;
        string website;
        string icon;
    }

    /**
     * @notice Deposits assets into the underlying protocol.
     * @param token The address of the token to deposit.
     * @param amount The amount of tokens to deposit.
     * @param data Additional data required by the protocol (optional).
     * @return amountOut The amount of receipt tokens or liquidity received.
     */
    function deposit(address token, uint256 amount, bytes calldata data)
        external
        returns (uint256 amountOut, address shareToken);

    /**
     * @notice Withdraws assets from the underlying protocol.
     * @param token The address of the token to withdraw.
     * @param amount The amount of tokens (or shares) to withdraw.
     * @param data Additional data required by the protocol (optional).
     * @return amountReceived The actual amount of underlying tokens received.
     */
    function withdraw(address token, uint256 amount, bytes calldata data) external returns (uint256 amountReceived);

    /**
     * @notice Returns metadata about the protocol.
     */
    function getProtocolInfo() external view returns (ProtocolInfo memory);

    /**
     * @notice Returns the current Supply APY for the given token in 1e18 scale.
     */
    function getSupplyApy(address token) external view returns (uint256);
}
