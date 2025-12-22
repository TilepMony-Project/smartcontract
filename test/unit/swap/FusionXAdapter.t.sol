// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {FusionXAdapter} from "../../../src/swap/adapters/FusionXAdapter.sol";
import {FusionXRouter} from "../../../src/swap/routers/FusionXRouter.sol";
import {TokenHypERC20} from "../../../src/token/TokenHypERC20.sol";
import {TokenHypTestBase} from "../../mocks/TokenHypTestBase.sol";

contract FusionXAdapterTest is TokenHypTestBase {
    address constant AGGREGATOR = address(0xAA);
    address constant RECEIVER = address(0xBB);
    address constant DEPLOYER = address(0x1);

    TokenHypERC20 tokenA;
    TokenHypERC20 tokenB;
    FusionXRouter router;
    FusionXAdapter adapter;

    uint256 constant AMOUNT_IN = 100 * 10 ** 6; // 100 tokens
    uint256 constant EXCHANGE_RATE = 2 * 10 ** 18; // 1 TokenA = 2 TokenB
    uint256 constant MIN_AMOUNT_OUT = 199 * 10 ** 6; // Expect 200, tolerate 199
    uint256 constant RATE_DECIMAL = 1e18;
    uint256 constant EXPECTED_OUT = AMOUNT_IN * EXCHANGE_RATE / RATE_DECIMAL;

    function setUp() public {
        vm.startPrank(DEPLOYER);
        tokenA = _deployToken("Mock IDRX", "MocIDRX");
        tokenB = _deployToken("Mock USDT", "MocUSDT");
        router = new FusionXRouter();
        adapter = new FusionXAdapter(address(router));
        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        vm.stopPrank();

        _mintTo(tokenA, AGGREGATOR, AMOUNT_IN);
        _mintTo(tokenB, address(router), EXPECTED_OUT);

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
