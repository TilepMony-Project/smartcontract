// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface MockIDRX {
    function giveMe(uint256 amount) external;
}

interface IYieldMock {
    function setExchangeRate(uint256) external;
}

contract YieldLiquidityInjector is Script {
    struct Config {
        string name;
        address vault;
        address token;
        uint256 amount;
    }

    function run(address vault, address token, uint256 newRate, uint256 amountToInject) external {
        // Targeted run for testing
        // 1. Inject Liquidity
        _mintTo(token, vault, amountToInject);

        // 2. Set Rate
        try IYieldMock(vault).setExchangeRate(newRate) {
            console.log("Success: Exchange rate set to", newRate);
        } catch {
            console.log("Error: Set Exchange Rate failed.");
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey); // Get deployer address
        vm.startBroadcast(deployerPrivateKey);

        // Tokens (Mantle Sepolia)
        address idrx = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
        address usdc = 0x681db03Ef13e37151e9fd68920d2c34273194379;
        address usdt = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

        // Amounts
        uint256 amountIdrx = 1_000_000_000 * 1e6;
        uint256 amountUsd = 1_000_000 * 1e6;

        // Common Rate
        uint256 newRate = 1.1 * 1e18; // 1.1e18

        Config[] memory configs = new Config[](9);

        // MethLab
        configs[0] = Config({
            name: "MethLab IDRX", vault: 0xBe97818D0B6577410b7282F9306Ea9ed8967d56a, token: idrx, amount: amountIdrx
        });
        configs[1] = Config({
            name: "MethLab USDC", vault: 0xDE28623E3A209062479C4CD3240eD14819309D66, token: usdc, amount: amountUsd
        });
        configs[2] = Config({
            name: "MethLab USDT", vault: 0x30f42E2f1931324aBC0ee9975FF63C552ab50ab7, token: usdt, amount: amountUsd
        });

        // Init Capital (MockLendingPool)
        configs[3] = Config({
            name: "InitCapital IDRX", vault: 0x6Adaa6312b785fcbf4904BA505Ecff4f3fe2b4e2, token: idrx, amount: amountIdrx
        });
        configs[4] = Config({
            name: "InitCapital USDC", vault: 0x2e01d3672be5978a0CcEada25097325f255F76e8, token: usdc, amount: amountUsd
        });
        configs[5] = Config({
            name: "InitCapital USDT", vault: 0x99a13d0D22025EbeE7958BE133022Aa17E63a821, token: usdt, amount: amountUsd
        });

        // Compound (MockComet)
        configs[6] = Config({
            name: "Compound IDRX", vault: 0xAaeBE3d3A7DFcC4c2C334E007dc4339d7669a411, token: idrx, amount: amountIdrx
        });
        configs[7] = Config({
            name: "Compound USDC", vault: 0x375b705311059aadaC34fe4BEa3C569adc4dcA8D, token: usdc, amount: amountUsd
        });
        configs[8] = Config({
            name: "Compound USDT", vault: 0xC88C22A769FB69fD6Ed690E927f3F1CCCaDF9180, token: usdt, amount: amountUsd
        });

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory c = configs[i];
            console.log("--- Processing:", c.name, "---");
            console.log("Vault:", c.vault);
            console.log("Token:", c.token);
            console.log("Amount:", c.amount);

            // 1. Inject Liquidity to Vault - Robust Method
            console.log("Attempting to inject liquidity to vault...");
            _mintTo(c.token, c.vault, c.amount);

            // 2. Set Exchange Rate
            console.log("Setting exchange rate...");
            try IYieldMock(c.vault).setExchangeRate(newRate) {
                console.log("Success: Exchange rate set to 1.1");
            } catch {
                console.log("Error: Set Exchange Rate failed.");
            }
            // 3. Fund Deployer & Mint Shares (Simulate User)
            console.log("Funding deployer and minting shares...");
            // Mint underlying to deployer first
            _mintTo(c.token, deployer, c.amount); // Fund deployer with same amount as liquidity

            // Approve Vault to spend deployer's tokens
            try IERC20(c.token).approve(c.vault, type(uint256).max) {
                // Mint Shares
                // Need to handle different minting interfaces if they vary, but assuming standard yield mock mint/deposit
                // MethLab/Init/Comet mocks usually have mint(to, amount) or similar.
                // Let's try to call mint(deployer, amount) on the vault.
                // Initial amount for shares.
                // uint256 shareAmount = (c.amount * 1e18) / newRate; // Approx calculation
                // Use a smaller fixed amount for testing to avoid hitting limits
                uint256 testShareAmount = 1000 * 1e6;
                if (i >= 3 && i <= 5) {
                    // Init Capital often uses 18 decimals or underlying? Mocks usually underlying.
                    // Check init decimals.
                }

                // Try minting shares
                (bool success,) =
                    c.vault.call(abi.encodeWithSignature("mint(address,uint256)", deployer, testShareAmount));
                if (success) {
                    console.log("Success: Minted shares to deployer.");
                } else {
                    console.log(
                        "Warning: Failed to mint shares to deployer contract might not support mint(address,uint256)"
                    );
                }
            } catch {
                console.log("Error: Approval failed.");
            }
        }

        vm.stopBroadcast();
    }

    // Helper to robustly mint tokens
    function _mintTo(address token, address to, uint256 amount) internal {
        // Method 1: giveMe + transfer (Preferred for Mocks in this system)
        (bool success,) = token.call(abi.encodeWithSignature("giveMe(uint256)", amount));
        if (success) {
            // giveMe usually gives to msg.sender (this script contract or deployer?)
            // if broadcast is active, msg.sender is deployer EOA.
            // If giveMe gives to msg.sender, we just need to transfer if 'to' is different.
            if (to != msg.sender) {
                bool transferSuccess = IERC20(token).transfer(to, amount);
                if (transferSuccess) {
                    console.log("Minted (via giveMe + transfer) to:", to);
                    return;
                } else {
                    console.log("Transfer failed after giveMe.");
                }
            } else {
                console.log("Minted (via giveMe) to self:", to);
                return;
            }
        }

        // Method 2: mint(to, amount) (Standard MockERC20)
        (bool mintSuccess,) = token.call(abi.encodeWithSignature("mint(address,uint256)", to, amount));
        if (mintSuccess) {
            console.log("Minted (via mint) directly to:", to);
            return;
        }

        console.log("FAILED to mint tokens to:", to);
    }
}
