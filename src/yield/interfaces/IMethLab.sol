// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMethLab {
    /**
     * @notice Deposits assets into the vault.
     * @param amount The amount of assets to deposit.
     * @param receiver The address to receive the shares.
     * @return shares The amount of shares minted.
     */
    function deposit(
        uint256 amount,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @notice Withdraws assets from the vault.
     * @param shares The amount of shares to burn.
     * @param receiver The address to receive the assets.
     * @return assets The amount of assets withdrawn.
     */
    function withdraw(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    /**
     * @notice Returns the amount of assets that the given amount of shares is worth.
     * @param shares The amount of shares to convert.
     * @return assets The amount of assets.
     */
    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets);

    /**
     * @notice Returns the amount of shares that the given amount of assets would buy.
     * @param assets The amount of assets to convert.
     * @return shares The amount of shares.
     */
    function convertToShares(
        uint256 assets
    ) external view returns (uint256 shares);

    /**
     * @notice Returns the current APY of the vault (Mock/Testnet only).
     * @return apy The current APY in 1e18 format.
     */
    function getAPY() external view returns (uint256 apy);
}
