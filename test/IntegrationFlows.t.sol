// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MainController} from "../src/core/MainController.sol";
import {IMainController} from "../src/interfaces/IMainController.sol";
import {SwapAggregator} from "../src/swap/SwapAggregator.sol";
import {MockERC20} from "../src/yield/mocks/MockERC20.sol";
import {ISwapAdapter} from "../src/swap/interfaces/ISwapAdapter.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Simple Swap Adapter for testing
contract TestSwapAdapter is ISwapAdapter {
    using SafeERC20 for IERC20;

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 /* minAmountOut */,
        address from,
        address to
    ) external returns (uint256 amountOut) {
        // Mock swap: 1:1 ratio
        IERC20(tokenIn).safeTransferFrom(from, address(this), amountIn);
        MockERC20(tokenOut).mint(to, amountIn); // Mint output to 'to'
        return amountIn;
    }
}

contract IntegrationFlows is Test {
    using SafeERC20 for IERC20;

    MainController controller;
    SwapAggregator swapAggregator;
    TestSwapAdapter testSwapAdapter;

    MockERC20 usdt;
    MockERC20 idrx;

    address user = address(0x123);
    address recipient = address(0x456);

    function setUp() public {
        vm.startPrank(user);

        // 1. Deploy Tokens
        usdt = new MockERC20("USDT", "USDT", 18);
        idrx = new MockERC20("IDRX", "IDRX", 18);

        // 2. Deploy Swap Components
        swapAggregator = new SwapAggregator();
        testSwapAdapter = new TestSwapAdapter();
        swapAggregator.addTrustedAdapter(address(testSwapAdapter));

        // 3. Deploy Controller
        controller = new MainController(user);

        vm.stopPrank();
    }

    // Scenario 1: External Source (Mint)
    // Flow: Mint IDRX -> Swap IDRX to USDT -> Transfer USDT to Recipient
    function test_Flow_MintSource() public {
        vm.startPrank(user);

        // 1. Define Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            3
        );

        // Action 0: MINT IDRX (Fake external source)
        bytes memory mintData = abi.encode(address(idrx), 1000 * 1e18);
        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(idrx),
            data: mintData,
            inputAmountPercentage: 0
        });

        // Action 1: SWAP IDRX -> USDT
        bytes memory swapData = abi.encode(
            address(testSwapAdapter),
            address(idrx),
            address(usdt),
            0,
            0,
            address(0) // Keep in controller for next step
        );
        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000 // 100%
        });

        // Action 2: TRANSFER USDT -> Recipient
        bytes memory transferData = abi.encode(address(usdt));
        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: recipient,
            data: transferData,
            inputAmountPercentage: 10000 // 100%
        });

        // 2. Execute with initialAmount = 0 (Crucial for MINT source)
        controller.executeWorkflow(actions, address(0), 0);

        // 3. Verify
        assertEq(
            usdt.balanceOf(recipient),
            1000 * 1e18,
            "Recipient should receive swapped USDT"
        );
        assertEq(
            idrx.balanceOf(address(controller)),
            0,
            "Controller should have no IDRX left"
        );

        vm.stopPrank();
    }

    // Scenario 2: Wallet Source
    // Flow: User Wallet (IDRX) -> Swap IDRX to USDT -> Transfer USDT to Recipient
    function test_Flow_WalletSource() public {
        vm.startPrank(user);

        // Setup: User has IDRX and approves controller
        idrx.mint(user, 500 * 1e18);
        idrx.approve(address(controller), 500 * 1e18);

        // 1. Define Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            2
        );

        // Action 0: SWAP IDRX -> USDT
        bytes memory swapData = abi.encode(
            address(testSwapAdapter),
            address(idrx),
            address(usdt),
            0,
            0,
            address(0)
        );
        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000
        });

        // Action 1: TRANSFER USDT -> Recipient
        bytes memory transferData = abi.encode(address(usdt));
        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: recipient,
            data: transferData,
            inputAmountPercentage: 10000
        });

        // 2. Execute with initialAmount > 0 (Pull from wallet)
        controller.executeWorkflow(actions, address(idrx), 500 * 1e18);

        // 3. Verify
        assertEq(
            usdt.balanceOf(recipient),
            500 * 1e18,
            "Recipient should receive swapped USDT"
        );
        assertEq(idrx.balanceOf(user), 0, "User should have spent IDRX");

        vm.stopPrank();
    }
}
