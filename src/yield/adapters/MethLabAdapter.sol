// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IMethLab} from "../interfaces/IMethLab.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MethLabAdapter is IYieldAdapter {
    mapping(address => address) public underlyingToVault;

    error VaultNotFound(address token);

    constructor() {}

    function setVault(address token, address vault) external {
        underlyingToVault[token] = vault;
    }

    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        address vault = underlyingToVault[token];
        if (vault == address(0)) revert VaultNotFound(token);

        // 1. Transfer tokens from Router to this adapter
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // 2. Approve vault to spend tokens
        IERC20(token).approve(vault, amount);

        // 3. Deposit into MethLab Vault
        // Shares are minted to this adapter
        return IMethLab(vault).deposit(amount, address(this));
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        address vault = underlyingToVault[token];
        if (vault == address(0)) revert VaultNotFound(token);

        // 1. Withdraw from MethLab Vault
        // 'amount' here is treated as shares amount to burn
        try IMethLab(vault).withdraw(amount, address(this)) returns (
            uint256 assetsReceived
        ) {
            // 2. Transfer underlying tokens to Router (msg.sender)
            IERC20(token).transfer(msg.sender, assetsReceived);
            return assetsReceived;
        } catch Error(string memory reason) {
            revert(reason);
        } catch (bytes memory lowLevelData) {
            // Forward the low-level revert (e.g. custom error FundsLocked)
            assembly {
                revert(add(lowLevelData, 32), mload(lowLevelData))
            }
        }
    }

    function getProtocolInfo()
        external
        pure
        override
        returns (ProtocolInfo memory)
    {
        return
            ProtocolInfo({
                name: "MethLab",
                // Updated description to reflect the unique nature of MethLab's yield
                description: "Fixed Term/Rate Lending. APY is a Target Rate and depends on utilization.",
                website: "https://methlab.xyz",
                icon: "methlab_icon_url"
            });
    }

    function getSupplyAPY(address token) external view returns (uint256) {
        address vault = underlyingToVault[token];
        if (vault == address(0)) return 0;

        // NOTE: In Mainnet/Production, this function should query the Strategy contract associated with the DLV.
        // Formula: Real APY = Strategy.interestRate * UtilizationRate

        // For this Mock/Testnet implementation, we query the mock's APY directly.
        // We use a low-level call or try/catch in view to be safe if the vault doesn't support getAPY
        // But since we know it's our MockMethLab, we can call it directly.
        try IMethLab(vault).getAPY() returns (uint256 apy) {
            return apy;
        } catch {
            return 0;
        }
    }
}
