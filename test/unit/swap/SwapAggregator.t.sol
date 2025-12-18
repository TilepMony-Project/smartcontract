// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ISwapRouter} from "../../../src/swap/interfaces/ISwapRouter.sol";
import {ISwapAdapter} from "../../../src/swap/interfaces/ISwapAdapter.sol";
import {FusionXRouter} from "../../../src/swap/routers/FusionXRouter.sol";
import {MerchantMoeRouter} from "../../../src/swap/routers/MerchantMoeRouter.sol";
import {VertexRouter} from "../../../src/swap/routers/VertexRouter.sol";
import {FusionXAdapter} from "../../../src/swap/adapters/FusionXAdapter.sol";
import {MerchantMoeAdapter} from "../../../src/swap/adapters/MerchantMoeAdapter.sol";
import {VertexAdapter} from "../../../src/swap/adapters/VertexAdapter.sol";
import {SwapAggregator} from "../../../src/swap/SwapAggregator.sol";
import {MockIDRX} from "../../../src/token/MockIDRX.sol";
import {MockUSDT} from "../../../src/token/MockUSDT.sol";

contract SwapAggregatorTest is Test {
    address constant SENDER = address(0xAA);
    address constant RECEIVER = address(0xBB);
    address constant DEPLOYER = address(0x1);

    MockIDRX tokenA;
    MockUSDT tokenB;
    ISwapRouter router;
    ISwapAdapter adapter;
    SwapAggregator aggregator;

    uint256 constant AMOUNT_IN = 100 * 10 ** 6; // 100 tokens
    uint256 constant EXCHANGE_RATE = 2 * 10 ** 18; // 1 TokenA = 2 TokenB
    uint256 constant MIN_AMOUNT_OUT = 199 * 10 ** 6; // Expect 200, tolerate 199
    uint256 constant RATE_DECIMAL = 1e18;
    uint256 constant EXPECTED_OUT = AMOUNT_IN * EXCHANGE_RATE / RATE_DECIMAL;

    function setUp() public {
        tokenA = new MockIDRX();
        tokenB = new MockUSDT();
        vm.prank(DEPLOYER);
        aggregator = new SwapAggregator();
    }

    function setUpFusionX() internal {
        vm.startPrank(DEPLOYER);

        router = new FusionXRouter();
        adapter = new FusionXAdapter(address(router));

        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        aggregator.addTrustedAdapter(address(adapter));
        tokenA.mint(SENDER, 1000 * 10 ** 6);
        tokenB.mint(address(router), 1000000 * 10 ** 6);

        vm.stopPrank();
    }

    function setUpMerchantMoe() internal {
        vm.startPrank(DEPLOYER);

        router = new MerchantMoeRouter();
        adapter = new MerchantMoeAdapter(address(router));

        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        aggregator.addTrustedAdapter(address(adapter));
        tokenA.mint(SENDER, 1000 * 10 ** 6);
        tokenB.mint(address(router), 1000000 * 10 ** 6);

        vm.stopPrank();
    }

    function setUpVertex() internal {
        vm.startPrank(DEPLOYER);

        router = new VertexRouter();
        adapter = new VertexAdapter(address(router));

        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        aggregator.addTrustedAdapter(address(adapter));
        tokenA.mint(SENDER, 1000 * 10 ** 6);
        tokenB.mint(address(router), 1000000 * 10 ** 6);

        vm.stopPrank();
    }

    function test_SuccesfulSwapThroughAggregator_FusionX() public {
        setUpFusionX();

        vm.startPrank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        uint256 senderTokenABalanceBefore = tokenA.balanceOf(SENDER);
        uint256 receiverTokenBBalanceBefore = tokenB.balanceOf(RECEIVER);

        uint256 amountOut = aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, RECEIVER
        );

        vm.stopPrank();

        assertEq(amountOut, EXPECTED_OUT, "Actual amount out must match expected amount");

        assertEq(tokenA.balanceOf(SENDER), senderTokenABalanceBefore - AMOUNT_IN, "User TokenA balance incorrect");
        assertEq(
            tokenB.balanceOf(RECEIVER), receiverTokenBBalanceBefore + EXPECTED_OUT, "Receiver TokenB balance incorrect"
        );

        assertEq(tokenA.balanceOf(address(aggregator)), 0, "Aggregator should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(adapter)), 0, "Adapter should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(router)), AMOUNT_IN, "Router should hold the input TokenA");
    }

    function test_SuccesfulSwapThroughAggregator_MerchantMoe() public {
        setUpMerchantMoe();

        vm.startPrank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        uint256 senderTokenABalanceBefore = tokenA.balanceOf(SENDER);
        uint256 receiverTokenBBalanceBefore = tokenB.balanceOf(RECEIVER);

        uint256 amountOut = aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, RECEIVER
        );

        vm.stopPrank();

        assertEq(amountOut, EXPECTED_OUT, "Actual amount out must match expected amount");

        assertEq(tokenA.balanceOf(SENDER), senderTokenABalanceBefore - AMOUNT_IN, "User TokenA balance incorrect");
        assertEq(
            tokenB.balanceOf(RECEIVER), receiverTokenBBalanceBefore + EXPECTED_OUT, "Receiver TokenB balance incorrect"
        );

        assertEq(tokenA.balanceOf(address(aggregator)), 0, "Aggregator should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(adapter)), 0, "Adapter should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(router)), AMOUNT_IN, "Router should hold the input TokenA");
    }

    function test_SuccesfulSwapThroughAggregator_Vertex() public {
        setUpVertex();

        vm.startPrank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        uint256 senderTokenABalanceBefore = tokenA.balanceOf(SENDER);
        uint256 receiverTokenBBalanceBefore = tokenB.balanceOf(RECEIVER);

        uint256 amountOut = aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, RECEIVER
        );

        vm.stopPrank();

        assertEq(amountOut, EXPECTED_OUT, "Actual amount out must match expected amount");

        assertEq(tokenA.balanceOf(SENDER), senderTokenABalanceBefore - AMOUNT_IN, "User TokenA balance incorrect");
        assertEq(
            tokenB.balanceOf(RECEIVER), receiverTokenBBalanceBefore + EXPECTED_OUT, "Receiver TokenB balance incorrect"
        );

        assertEq(tokenA.balanceOf(address(aggregator)), 0, "Aggregator should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(adapter)), 0, "Adapter should have 0 TokenA remaining");
        assertEq(tokenA.balanceOf(address(router)), AMOUNT_IN, "Router should hold the input TokenA");
    }

    function test_RevertWhen_SwapWithUntrustedAdapter() public {
        setUpFusionX();

        vm.prank(DEPLOYER);
        VertexRouter untrustedRouter = new VertexRouter();
        vm.prank(DEPLOYER);
        VertexAdapter untrustedAdapter = new VertexAdapter(address(untrustedRouter));

        vm.prank(DEPLOYER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        vm.expectRevert("SwapAggregator: untrusted adapter");

        vm.prank(SENDER);
        aggregator.swapWithProvider(
            address(untrustedAdapter), address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, RECEIVER
        );
    }

    function test_RevertWhen_SlippageTooHigh_FusionX() public {
        setUpFusionX();

        uint256 highSlippageAmount = 201 * 10 ** 6;

        vm.prank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        vm.expectRevert("FusionXRouter: slippage too high");

        vm.prank(SENDER);
        aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, highSlippageAmount, RECEIVER
        );
    }

    function test_RevertWhen_SlippageTooHigh_MerchantMoe() public {
        setUpMerchantMoe();

        uint256 highSlippageAmount = 201 * 10 ** 6;

        vm.prank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        vm.expectRevert("MerchantMoeRouter: slippage too high");

        vm.prank(SENDER);
        aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, highSlippageAmount, RECEIVER
        );
    }

    function test_RevertWhen_SlippageTooHigh_Vertex() public {
        setUpVertex();

        uint256 highSlippageAmount = 201 * 10 ** 6;

        vm.prank(SENDER);
        tokenA.approve(address(aggregator), AMOUNT_IN);

        vm.expectRevert("VertexRouter: slippage too high");

        vm.prank(SENDER);
        aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, highSlippageAmount, RECEIVER
        );
    }

    function test_RevertWhen_InsufficientUserApproval() public {
        setUpVertex();

        uint256 insufficientApproval = AMOUNT_IN - 1;
        vm.prank(SENDER);
        tokenA.approve(address(aggregator), insufficientApproval);

        vm.expectRevert();

        vm.prank(SENDER);
        aggregator.swapWithProvider(
            address(adapter), address(tokenA), address(tokenB), AMOUNT_IN, MIN_AMOUNT_OUT, RECEIVER
        );
    }
}
