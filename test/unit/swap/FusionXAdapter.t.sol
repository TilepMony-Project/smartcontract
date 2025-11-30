// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {FusionXAdapter} from "../../../src/swap/adapters/FusionXAdapter.sol";
import {FusionXRouter} from "../../../src/swap/routers/FusionXRouter.sol";
import {MockIDRX} from "../../../src/token/MockIDRX.sol";
import {MockUSDT} from "../../../src/token/MockUSDT.sol";

contract FusionXAdapterTest is Test {
    address constant AGGREGATOR = address(0xAA);
    address constant RECEIVER = address(0xBB);
    address constant DEPLOYER = address(0x1);

    MockIDRX tokenA;
    MockUSDT tokenB;
    FusionXRouter router;
    FusionXAdapter adapter;

    uint256 constant AMOUNT_IN = 100 * 10 ** 6; // 100 tokens
    uint256 constant EXCHANGE_RATE = 2; // 1 TokenA = 2 TokenB
    uint256 constant MIN_AMOUNT_OUT = 199 * 10 ** 6; // Expect 200, tolerate 199
    uint256 constant EXPECTED_OUT = AMOUNT_IN * EXCHANGE_RATE;

    function setUp() public {
        vm.startPrank(DEPLOYER);
        tokenA = new MockIDRX();
        tokenB = new MockUSDT();
        router = new FusionXRouter();
        adapter = new FusionXAdapter(address(router));
        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        tokenA.mint(AGGREGATOR, AMOUNT_IN);
        tokenB.mint(address(router), EXPECTED_OUT);
        vm.stopPrank();

        vm.prank(AGGREGATOR);
        tokenA.approve(address(adapter), AMOUNT_IN);
    }

    function test_SuccessfulSwap_AdapterLogic() public {
        uint256 aggregatorTokenABalanceBefore = tokenA.balanceOf(AGGREGATOR);
        uint256 adapterTokenABalanceBefore = tokenA.balanceOf(address(adapter));
        uint256 receiverTokenBBalanceBefore = tokenB.balanceOf(RECEIVER);

        vm.prank(AGGREGATOR);
        uint256 amountOut =
            adapter.swap(address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, AGGREGATOR, RECEIVER);

        assertEq(amountOut, EXPECTED_OUT, "Adapter returned amountOut incorrect");

        assertEq(
            tokenA.balanceOf(AGGREGATOR),
            aggregatorTokenABalanceBefore - AMOUNT_IN,
            "Aggregator TokenA balance incorrect"
        );
        assertEq(tokenA.balanceOf(address(adapter)), adapterTokenABalanceBefore, "Adapter TokenA balance should be 0");
        assertEq(
            tokenB.balanceOf(RECEIVER), receiverTokenBBalanceBefore + EXPECTED_OUT, "Receiver TokenB balance incorrect"
        );
    }

    function test_RevertWhen_InsufficientAggregatorApproval() public {
        vm.prank(AGGREGATOR);
        tokenA.approve(address(adapter), 0);

        vm.expectRevert();

        vm.prank(AGGREGATOR);
        adapter.swap(address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, AGGREGATOR, RECEIVER);

        vm.stopPrank();
    }
}
