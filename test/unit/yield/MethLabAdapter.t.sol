// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MethLabAdapter} from "../../../src/yield/adapters/MethLabAdapter.sol";
import {MockMethLab} from "../../../src/yield/mocks/MockMethLab.sol";
import {MockERC20} from "../../../src/yield/mocks/MockERC20.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";

contract MethLabAdapterTest is Test {
    MethLabAdapter adapter;
    MockMethLab methLabVault;
    MockERC20 usdc;
    YieldRouter router;
    address user = address(0x1);

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        methLabVault = new MockMethLab(address(usdc));
        adapter = new MethLabAdapter();
        router = new YieldRouter();

        // Setup Adapter
        adapter.setVault(address(usdc), address(methLabVault));

        // Setup Router
        router.setAdapterWhitelist(address(adapter), true);

        // Mint tokens to user
        usdc.mint(user, 10000 * 1e6);

        vm.prank(user);
        usdc.approve(address(router), type(uint256).max);
    }

    function testDeposit() public {
        console.log("--- Testing Deposit ---");
        uint256 amount = 1000 * 1e6;

        console.log("User Balance Before:", usdc.balanceOf(user));
        console.log(
            "Vault Balance Before:",
            usdc.balanceOf(address(methLabVault))
        );

        vm.prank(user);
        uint256 shares = router.deposit(
            address(adapter),
            address(usdc),
            amount,
            ""
        );

        console.log("Deposited Amount:", amount);
        console.log("Shares Received:", shares);
        console.log("User Balance After:", usdc.balanceOf(user));
        console.log(
            "Vault Balance After:",
            usdc.balanceOf(address(methLabVault))
        );

        assertEq(usdc.balanceOf(address(methLabVault)), amount);
        // Initial exchange rate is 1:1, but scaled by 1e18 in mock
        // 1000 * 1e6 * 1e18 / 1e18 = 1000 * 1e6
        assertEq(shares, amount);
    }

    function testWithdraw() public {
        console.log("--- Testing Withdraw ---");
        uint256 amount = 1000 * 1e6;

        vm.prank(user);
        uint256 shares = router.deposit(
            address(adapter),
            address(usdc),
            amount,
            ""
        );

        console.log("Initial Deposit Shares:", shares);

        // Simulate yield by changing exchange rate
        // 1 share = 1.1 asset
        methLabVault.setExchangeRate(1.1e18);
        console.log("Exchange Rate updated to 1.1");

        uint256 withdrawShares = shares / 2;
        console.log("Withdrawing Shares:", withdrawShares);

        vm.startPrank(user);
        methLabVault.approve(address(router), withdrawShares);
        uint256 assetsReceived = router.withdraw(
            address(adapter),
            address(methLabVault),
            address(usdc),
            withdrawShares,
            ""
        );
        vm.stopPrank();

        console.log("Assets Received:", assetsReceived);
        console.log("User Balance After Withdraw:", usdc.balanceOf(user));

        // Expected: shares * 1.1
        // shares is 1000 * 1e6
        // withdrawShares is 500 * 1e6
        // assets = 500 * 1e6 * 1.1 = 550 * 1e6
        uint256 expectedAssets = (withdrawShares * 11) / 10;
        assertEq(assetsReceived, expectedAssets);
    }

    function testGetSupplyAPY() public {
        console.log("--- Testing APY ---");

        // Default APY
        uint256 apy = adapter.getSupplyApy(address(usdc));
        console.log("Default APY:", apy);
        assertEq(apy, 5e16);

        // Update APY
        methLabVault.setApy(10e16); // 10%
        apy = adapter.getSupplyApy(address(usdc));
        console.log("Updated APY:", apy);
        assertEq(apy, 10e16);
    }

    function testLockedFunds() public {
        console.log("--- Testing Locked Funds ---");
        uint256 amount = 1000 * 1e6;

        vm.prank(user);
        uint256 shares = router.deposit(
            address(adapter),
            address(usdc),
            amount,
            ""
        );

        // Lock funds for 1 day
        uint256 unlockTime = block.timestamp + 1 days;
        methLabVault.setLock(unlockTime);
        console.log("Funds Locked Until:", unlockTime);

        // Try to withdraw (should fail)
        // Try to withdraw (should fail)
        vm.startPrank(user);
        methLabVault.approve(address(router), shares); // Approve first
        vm.expectRevert(
            abi.encodeWithSelector(MockMethLab.FundsLocked.selector, unlockTime)
        );
        router.withdraw(
            address(adapter),
            address(methLabVault),
            address(usdc),
            shares,
            ""
        );
        vm.stopPrank();
        console.log("Withdraw failed as expected (Funds Locked)");

        // Fast forward time
        vm.warp(unlockTime + 1);
        console.log("Time warped to:", block.timestamp);

        // Withdraw should succeed now
        vm.startPrank(user);
        // Approval persists? Or re-approve?
        // Since revert happened, approval might be rolled back? No, expectRevert catches it.
        // But let's re-approve to be safe or check allowance.
        // Actually, if expectRevert works, state is reverted, so approval is GONE.
        methLabVault.approve(address(router), shares);
        uint256 assetsReceived = router.withdraw(
            address(adapter),
            address(methLabVault),
            address(usdc),
            shares,
            ""
        );
        vm.stopPrank();
        console.log("Withdraw success after unlock. Assets:", assetsReceived);
        assertEq(assetsReceived, amount); // 1:1 since no yield simulated here
    }
}
