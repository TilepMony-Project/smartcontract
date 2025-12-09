// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../src/yield/mocks/MockERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IYieldMock {
    function setExchangeRate(uint256) external;
}

contract YieldLiquidityInjector is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Target Vaults (Set these in .env or pass via CLI)
        address targetVault = vm.envAddress("TARGET_VAULT");
        address targetToken = vm.envAddress("TARGET_TOKEN");
        uint256 newRate = vm.envUint("NEW_RATE"); // e.g., 1.1e18
        uint256 injectAmount = vm.envUint("INJECT_AMOUNT"); // Raw units

        if (targetVault == address(0) || targetToken == address(0)) {
            console.log("Error: TARGET_VAULT and TARGET_TOKEN must be set.");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);
        run(targetVault, targetToken, newRate, injectAmount);
        vm.stopBroadcast();
    }

    function run(
        address targetVault,
        address targetToken,
        uint256 newRate,
        uint256 injectAmount
    ) public {
        console.log("--- Yield Liquidity Injector ---");
        console.log("Target Vault:", targetVault);
        console.log("Target Token:", targetToken);
        console.log("Inject Amount:", injectAmount);
        console.log("New Rate:", newRate);

        // 1. Inject Liquidity (Mint to Vault)
        try MockERC20(targetToken).mint(targetVault, injectAmount) {
            console.log("Success: Minted liquidity to vault.");
        } catch {
            console.log(
                "Warning: Failed to mint directly. Attempting transfer..."
            );
            // Fallback: If deployed token isn't mock-mintable by us, try transfer
            // (Requires deployer to have balance - caller must handle broadcast/prank)
            try IERC20(targetToken).transfer(targetVault, injectAmount) {
                console.log("Success: Transferred liquidity to vault.");
            } catch {
                console.log(
                    "Error: Failed to inject liquidity (Mint/Transfer failed)."
                );
            }
        }
        // 2. Set Exchange Rate
        try IYieldMock(targetVault).setExchangeRate(newRate) {
            console.log("Success: Exchange rate updated.");
        } catch {
            console.log(
                "Error: Failed to set exchange rate. Is the target a valid Mock?"
            );
        }
    }
}
