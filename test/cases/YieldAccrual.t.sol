// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {YieldRouter} from "../../src/yield/YieldRouter.sol";
import {MethLabAdapter} from "../../src/yield/adapters/MethLabAdapter.sol";
import {MockMethLab} from "../../src/yield/mocks/MockMethLab.sol";
import {MockERC20} from "../../src/yield/mocks/MockERC20.sol";
import {
    YieldLiquidityInjector
} from "../../script/YieldLiquidityInjector.s.sol";

contract YieldAccrualTest is Test {
    YieldRouter router;
    MethLabAdapter adapter;
    MockMethLab vault;
    MockERC20 usdc;
    address user = address(0x1);

    YieldLiquidityInjector injectorScript;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        vault = new MockMethLab(address(usdc), "MethLab Mock", "mMOCK");
        adapter = new MethLabAdapter();
        router = new YieldRouter();

        adapter.setVault(address(usdc), address(vault));
        router.setAdapterWhitelist(address(adapter), true);

        // Initial Liquidity
        usdc.mint(user, 1000 * 1e6);

        vm.prank(user);
        usdc.approve(address(router), type(uint256).max);

        injectorScript = new YieldLiquidityInjector();
    }

    function test_Workflow_Deposit_Inject_Withdraw() public {
        console.log("--- Start: Deposit -> Yield Injection -> Withdraw ---");

        // 1. User Deposits 1000 USDC
        vm.prank(user);
        (uint256 shares, ) = router.deposit(
            address(adapter),
            address(usdc),
            1000 * 1e6,
            ""
        );
        assertEq(shares, 1000 * 1e6, "Initial shares should be 1:1");

        // 2. Simulate Yield Injection (via Script Logic)
        // Rate 1.1 -> Need 1100 assets in vault. Vault currently has 1000.
        // Needs +100 inject.

        // Mock Env Vars for Script
        vm.setEnv("TARGET_VAULT", vm.toString(address(vault)));
        vm.setEnv("TARGET_TOKEN", vm.toString(address(usdc)));
        vm.setEnv("NEW_RATE", vm.toString(uint256(1.1e18)));
        vm.setEnv("INJECT_AMOUNT", vm.toString(uint256(100 * 1e6)));
        // Mock Private Key (arbitrary, script needs it)
        vm.setEnv(
            "PRIVATE_KEY",
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        );

        // Run Script
        injectorScript.run();

        // Verify Script Effects
        assertEq(vault.exchangeRate(), 1.1e18, "Exchange rate did not update");
        assertEq(
            usdc.balanceOf(address(vault)),
            1100 * 1e6,
            "Liquidity not injected correctly"
        );

        // 3. User Withdraws All
        vm.startPrank(user);
        vault.approve(address(router), shares);
        uint256 assetsReceived = router.withdraw(
            address(adapter),
            address(vault),
            address(usdc),
            shares,
            ""
        );
        vm.stopPrank();

        // 4. Verify Profit
        // 1000 Shares * 1.1 = 1100 Assets
        assertEq(assetsReceived, 1100 * 1e6, "User should have 10% profit");
        console.log("User received:", assetsReceived);
    }
}
