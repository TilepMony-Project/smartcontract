// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../src/yield/mocks/MockERC20.sol";
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

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Tokens
        address IDRX = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
        address USDC = 0x681db03Ef13e37151e9fd68920d2c34273194379;
        address USDT = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

        // Amounts
        uint256 amountIDRX = 1_000_000_000 * 1e6;
        uint256 amountUSD = 1_000_000 * 1e6;

        // Common Rate
        uint256 newRate = 1.1 * 1e18; // 1.1e18

        Config[] memory configs = new Config[](9);

        // MethLab
        configs[0] = Config(
            "MethLab IDRX",
            0x7069d4AB5B7795E0D3c66FDDD1aC3c3533690512,
            IDRX,
            amountIDRX
        );
        configs[1] = Config(
            "MethLab USDC",
            0xc9066bb1584d35828464B8481256dB977e32A4a0,
            USDC,
            amountUSD
        );
        configs[2] = Config(
            "MethLab USDT",
            0x11e5Bc89A961De706E26782692c08a0c6581392E,
            USDT,
            amountUSD
        );

        // Init Capital (MockLendingPool)
        configs[3] = Config(
            "InitCapital IDRX",
            0xb09df774c6dbc921076e73133c9759D3d12bB2F7,
            IDRX,
            amountIDRX
        );
        configs[4] = Config(
            "InitCapital USDC",
            0x9a8FfF643CB8de4F4C39cdAD55dbad099dB05E61,
            USDC,
            amountUSD
        );
        configs[5] = Config(
            "InitCapital USDT",
            0x03604c39dfB4Ea6874D935C6C8D2ac6B8aaF270E,
            USDT,
            amountUSD
        );

        // Compound (MockComet)
        configs[6] = Config(
            "Compound IDRX",
            0x6Bda7409B3dbfF5E763Efb093949D9D9e8A47309,
            IDRX,
            amountIDRX
        );
        configs[7] = Config(
            "Compound USDC",
            0xF12aA9E125F03D7838280835E8aCe0E9D6dd7183,
            USDC,
            amountUSD
        );
        configs[8] = Config(
            "Compound USDT",
            0x3e0f36a561df985Ee5eb63CC4Dd4eBF3fA033291,
            USDT,
            amountUSD
        );

        for (uint256 i = 0; i < configs.length; i++) {
            Config memory c = configs[i];
            console.log("--- Processing:", c.name, "---");
            console.log("Vault:", c.vault);
            console.log("Token:", c.token);
            console.log("Amount:", c.amount);

            // 1. Inject Liquidity
            console.log("Attempting giveMe and transfer...");
            try MockIDRX(c.token).giveMe(c.amount) {
                IERC20(c.token).transfer(c.vault, c.amount);
                console.log("Success: Used giveMe and transferred.");
            } catch {
                console.log(
                    "Warning: giveMe failed. Attempting direct mint..."
                );
                try MockERC20(c.token).mint(c.vault, c.amount) {
                    console.log("Success: Minted liquidity.");
                } catch {
                    console.log("Error: Injection failed.");
                }
            }
            // 2. Set Exchange Rate
            try IYieldMock(c.vault).setExchangeRate(newRate) {
                console.log("Success: Exchange rate set to 1.1");
            } catch {
                console.log("Error: Set Exchange Rate failed.");
            }
        }

        vm.stopBroadcast();
    }
}
