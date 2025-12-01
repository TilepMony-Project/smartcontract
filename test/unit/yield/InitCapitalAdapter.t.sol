// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {
    InitCapitalAdapter
} from "../../../src/yield/adapters/InitCapitalAdapter.sol";
import {MockInitCore} from "../../../src/yield/mocks/initCore/MockInitCore.sol";
import {
    MockLendingPool
} from "../../../src/yield/mocks/initCore/MockLendingPool.sol";
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
        lendingPool = new MockLendingPool(address(token));
        router = new YieldRouter();

        adapter = new InitCapitalAdapter(address(initCore));
        adapter.setPool(address(token), address(lendingPool));

        router.setAdapterWhitelist(address(adapter), true);

        token.mint(user, 10000 * 1e6);
        token.mint(address(lendingPool), 10000 * 1e6); // Liquidity for withdrawals

        vm.prank(user);
        token.approve(address(router), type(uint256).max);
    }

    function testDeposit() public {
        console.log("--- Testing Init Capital Deposit ---");
        uint256 amount = 100 * 1e6;

        vm.prank(user);
        uint256 amountOut = router.deposit(
            address(adapter),
            address(token),
            amount,
            ""
        );

        console.log("Amount Deposited:", amount);
        console.log("Amount Out (Shares):", amountOut);

        // Init Capital Mock mints 1:1 shares but mock returns fixed 100 ether
        assertEq(amountOut, 100 ether);
        // Token should be in LendingPool
        assertEq(token.balanceOf(address(lendingPool)), amount + 10000 * 1e6);
    }

    function testAPY() public {
        console.log("--- Testing Init Capital APY ---");
        // Set rate in mock lending pool
        // 5% APY -> 1.58e-9 per second -> 1585489599 scaled by 1e18
        uint256 targetRate = 1585489599;
        lendingPool.setSupplyRate(targetRate);

        uint256 apy = adapter.getSupplyAPY(address(token));
        console.log("Init Capital APY:", apy);
        // Should be approx 5% (5e16)
        // Note: The mock calculation in adapter might be slightly different depending on constants
        // 1585489599 * 365 * 24 * 3600 * 100 / 1e18 = 5
        assertApproxEqAbs(apy, 5, 1);
    }
}
