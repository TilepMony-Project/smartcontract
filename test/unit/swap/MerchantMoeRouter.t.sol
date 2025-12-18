// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MerchantMoeRouter} from "../../../src/swap/routers/MerchantMoeRouter.sol";
import {TokenHypERC20} from "../../../src/token/TokenHypERC20.sol";
import {TokenHypTestBase} from "../../mocks/TokenHypTestBase.sol";

contract MerchantMoeRouterTest is TokenHypTestBase {
    address constant ADAPTER = address(0xAA);
    address constant RECEIVER = address(0xBB);
    address constant DEPLOYER = address(0x1);

    TokenHypERC20 tokenA;
    TokenHypERC20 tokenB;
    MerchantMoeRouter router;

    uint256 constant AMOUNT_IN = 100 * 10 ** 6; // 100 tokens
    uint256 constant EXCHANGE_RATE = 2 * 10 ** 18; // 1 TokenA = 2 TokenB
    uint256 constant MIN_AMOUNT_OUT = 199 * 10 ** 6; // Expect 200, tolerate 199
    uint256 constant RATE_DECIMAL = 1e18;
    uint256 constant EXPECTED_OUT = AMOUNT_IN * EXCHANGE_RATE / RATE_DECIMAL;

    function setUp() public {
        vm.startPrank(DEPLOYER);
        tokenA = _deployToken("Mock IDRX", "MocIDRX");
        tokenB = _deployToken("Mock USDT", "MocUSDT");
        router = new MerchantMoeRouter();
        router.setRate(address(tokenA), address(tokenB), EXCHANGE_RATE);
        vm.stopPrank();

        _mintTo(tokenA, ADAPTER, AMOUNT_IN);
        _mintTo(tokenB, address(router), EXPECTED_OUT);

        vm.prank(ADAPTER);
        tokenA.approve(address(router), AMOUNT_IN);
    }

    function test_RateIsSetCorrectly() public view {
        assertEq(router.exchangeRate(address(tokenA), address(tokenB)), EXCHANGE_RATE);
    }

    function test_SuccessfulSwap_RouterLogic() public {
        uint256 adapterTokenABalanceBefore = tokenA.balanceOf(ADAPTER);
        uint256 routerTokenBBalanceBefore = tokenB.balanceOf(address(router));
        uint256 receiverTokenBBalanceBefore = tokenB.balanceOf(RECEIVER);

        vm.startPrank(ADAPTER);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256[] memory amounts = router.swapExactTokensForTokens(AMOUNT_IN, MIN_AMOUNT_OUT, path, RECEIVER);

        vm.stopPrank();

        assertEq(amounts[0], AMOUNT_IN, "Returned amountIn incorrect");
        assertEq(amounts[1], EXPECTED_OUT, "Returned amountOut incorrect");

        assertEq(tokenA.balanceOf(ADAPTER), adapterTokenABalanceBefore - AMOUNT_IN, "Adapter TokenA balance incorrect");
        assertEq(tokenA.balanceOf(address(router)), AMOUNT_IN, "Router should hold input TokenA");

        assertEq(
            tokenB.balanceOf(RECEIVER), receiverTokenBBalanceBefore + EXPECTED_OUT, "Adapter TokenA balance incorrect"
        );
        assertEq(
            tokenB.balanceOf(address(router)),
            routerTokenBBalanceBefore - EXPECTED_OUT,
            "Router TokenB balance incorrect"
        );
    }

    function test_RevertWhen_SlippageTooHigh() public {
        uint256 highSlippageAmount = EXPECTED_OUT + 1;

        vm.prank(ADAPTER);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert("MerchantMoeRouter: slippage too high");
        router.swapExactTokensForTokens(AMOUNT_IN, highSlippageAmount, path, RECEIVER);
    }

    function test_RevertWhen_NoRateSet() public {
        vm.prank(ADAPTER);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenA); // TokenA to TokenA has no rate set

        vm.expectRevert("MerchantMoeRouter: no exchange rate found");
        router.swapExactTokensForTokens(AMOUNT_IN, MIN_AMOUNT_OUT, path, RECEIVER);
    }
}
