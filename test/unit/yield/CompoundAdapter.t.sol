// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {CompoundAdapter} from "../../../src/yield/adapters/CompoundAdapter.sol";
import {MockComet} from "../../../src/yield/mocks/MockComet.sol";
import {MockERC20} from "../../../src/yield/mocks/MockERC20.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";

contract CompoundAdapterTest is Test {
    CompoundAdapter adapter;
    MockComet comet;
    MockERC20 token;
    YieldRouter router;
    address user = address(0x1);

    function setUp() public {
        token = new MockERC20("USDC", "USDC", 6);
        comet = new MockComet(address(token));
        router = new YieldRouter();

        adapter = new CompoundAdapter(address(comet));

        router.setAdapterWhitelist(address(adapter), true);

        token.mint(user, 10000 * 1e6);
        token.mint(address(comet), 10000 * 1e6); // Liquidity for withdrawals

        vm.prank(user);
        token.approve(address(router), type(uint256).max);
    }

    function testDeposit() public {
        console.log("--- Testing Compound Deposit ---");
        uint256 amount = 100 * 1e6;

        vm.prank(user);
        uint256 amountOut = router.deposit(
            address(adapter),
            address(token),
            amount,
            ""
        );

        console.log("Amount Deposited:", amount);
        console.log("Amount Out:", amountOut);

        assertEq(amountOut, amount);
        // Adapter supplies to Comet, so Comet balance increases
        assertEq(token.balanceOf(address(comet)), amount + 10000 * 1e6);
    }

    function testAPY() public {
        console.log("--- Testing Compound APY ---");
        // MockComet default supply rate is 1000000000 (1e9) per second
        // APY = (1e9 * 31536000 * 100) / 1e18 = 3.15%

        uint256 apy = adapter.getSupplyAPY();
        console.log("Compound APY:", apy);
        assertGt(apy, 0);
    }
    function testWithdraw() public {
        console.log("--- Testing Compound Withdraw ---");
        uint256 amount = 100 * 1e6;

        vm.prank(user);
        router.deposit(address(adapter), address(token), amount, "");

        console.log("Initial Deposit Amount:", amount);
        console.log(
            "Comet Balance After Deposit:",
            token.balanceOf(address(comet))
        );

        vm.prank(user);
        uint256 amountReceived = router.withdraw(
            address(adapter),
            address(token),
            amount,
            ""
        );

        console.log("Amount Received:", amountReceived);
        console.log(
            "Comet Balance After Withdraw:",
            token.balanceOf(address(comet))
        );

        assertEq(amountReceived, amount);
        // Comet balance should decrease by amount
        assertEq(token.balanceOf(address(comet)), 10000 * 1e6); // Back to initial liquidity
    }
}
