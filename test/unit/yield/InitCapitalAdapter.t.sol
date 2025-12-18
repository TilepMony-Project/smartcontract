// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {InitCapitalAdapter} from "../../../src/yield/adapters/InitCapitalAdapter.sol";
import {MockInitCore} from "../../../src/yield/mocks/initCore/MockInitCore.sol";
import {MockLendingPool} from "../../../src/yield/mocks/initCore/MockLendingPool.sol";
import {MockERC20} from "../../../src/yield/mocks/MockERC20.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";

contract InitCapitalAdapterTest is Test {
    InitCapitalAdapter adapter;
    MockInitCore initCore;
    MockLendingPool lendingPool;
    MockERC20 token;
    YieldRouter router;
    address user = address(0x1);

    function setUp() public {
        token = new MockERC20("USDT", "USDT", 6);
        initCore = new MockInitCore();
        lendingPool = new MockLendingPool(address(token), "Init Yield", "inMOCK");
        router = new YieldRouter();

        adapter = new InitCapitalAdapter(address(initCore));
        adapter.setPool(address(token), address(lendingPool));

        router.setAdapterWhitelist(address(adapter), true);

        token.mint(user, 10000 * 1e6);
        token.mint(address(lendingPool), 10000 * 1e6); // Liquidity for withdrawals
        // Sync shares
        lendingPool.mint(address(this), 10000 * 1e6);

        vm.prank(user);
        token.approve(address(router), type(uint256).max);

        // Approve InitCore to spend LendingPool's tokens (for withdraw mock)
        vm.prank(address(lendingPool));
        token.approve(address(initCore), type(uint256).max);
    }

    function testDeposit() public {
        console.log("--- Testing Init Capital Deposit ---");
        uint256 amount = 100 * 1e6;

        vm.prank(user);
        (uint256 amountOut,) = router.deposit(address(adapter), address(token), amount, "");

        console.log("Amount Deposited:", amount);
        console.log("Amount Out (Shares):", amountOut);

        // Init Capital Mock now uses dynamic 1:1 shares
        assertEq(amountOut, amount);
        // Token should be in LendingPool
        assertEq(token.balanceOf(address(lendingPool)), amount + 10000 * 1e6);
    }

    function testWithdraw() public {
        console.log("--- Testing Init Capital Withdraw ---");
        uint256 amount = 100 * 1e6;

        vm.prank(user);
        router.deposit(address(adapter), address(token), amount, "");

        console.log("Initial Deposit Amount:", amount);
        console.log("LendingPool Balance After Deposit:", token.balanceOf(address(lendingPool)));

        vm.startPrank(user);
        lendingPool.approve(address(router), 100 ether);
        // Withdraw 100 ether shares (which is what we got from deposit mock)
        uint256 amountReceived = router.withdraw(
            address(adapter),
            address(lendingPool),
            address(token),
            amount, // Withdraw actual amount deposited
            ""
        );
        vm.stopPrank();

        console.log("Amount Received:", amountReceived);
        console.log("LendingPool Balance After Withdraw:", token.balanceOf(address(lendingPool)));

        // MockInitCore returns 100 * 10**decimals (which is amount)
        assertEq(amountReceived, amount);
        // LendingPool balance should decrease by amount
        assertEq(token.balanceOf(address(lendingPool)), 10000 * 1e6); // Back to initial liquidity
    }

    function testAPY() public {
        console.log("--- Testing Init Capital APY ---");
        // Set rate in mock lending pool
        // 5% APY -> 1.58e-9 per second -> 1585489599 scaled by 1e18
        uint256 targetRate = 1585489599;
        lendingPool.setSupplyRate(targetRate);

        uint256 apy = adapter.getSupplyApy(address(token));
        console.log("Init Capital APY:", apy);
        // Should be approx 5% (5e16)
        // Note: The mock calculation in adapter might be slightly different depending on constants
        // 1585489599 * 365 * 24 * 3600 * 100 / 1e18 = 5
        assertApproxEqAbs(apy, 5, 1);
    }
}
