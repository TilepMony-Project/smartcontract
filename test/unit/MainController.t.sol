// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MainController} from "../../src/core/MainController.sol";
import {IMainController} from "../../src/interfaces/IMainController.sol";
import {SwapAggregator} from "../../src/swap/SwapAggregator.sol";
import {YieldRouter} from "../../src/yield/YieldRouter.sol";
import {MockERC20} from "../../src/yield/mocks/MockERC20.sol";
import {ISwapAdapter} from "../../src/swap/interfaces/ISwapAdapter.sol";
import {IYieldAdapter} from "../../src/yield/interfaces/IYieldAdapter.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// --- Test Adapters ---

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

contract TestYieldAdapter is IYieldAdapter {
    using SafeERC20 for IERC20;

    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external returns (uint256, address) {
        // Mock deposit: Burn token, return same amount as "shares" (just for tracking)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        return (amount, address(0));
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external returns (uint256) {
        IERC20(token).safeTransfer(msg.sender, amount);
        return amount;
    }

    function getProtocolInfo() external pure returns (ProtocolInfo memory) {
        return
            ProtocolInfo({
                name: "Test",
                description: "Test Desc",
                website: "https://test.com",
                icon: "icon.png"
            });
    }
}

// --- Main Test Suite ---

contract MainControllerTest is Test {
    MainController controller;
    SwapAggregator swapAggregator;
    YieldRouter yieldRouter;

    TestSwapAdapter testSwapAdapter;
    TestYieldAdapter testYieldAdapter;

    MockERC20 usdt;
    MockERC20 idrx;

    address user = address(0x123);

    function setUp() public {
        vm.startPrank(user);

        // 1. Deploy Tokens
        usdt = new MockERC20("USDT", "USDT", 18);
        idrx = new MockERC20("IDRX", "IDRX", 18);

        // 2. Deploy Aggregators
        swapAggregator = new SwapAggregator();
        yieldRouter = new YieldRouter();

        // 3. Deploy Test Adapters
        testSwapAdapter = new TestSwapAdapter();
        testYieldAdapter = new TestYieldAdapter();

        // 4. Whitelist Adapters
        swapAggregator.addTrustedAdapter(address(testSwapAdapter));
        yieldRouter.setAdapterWhitelist(address(testYieldAdapter), true);

        // 5. Deploy Controller
        controller = new MainController(user);

        vm.stopPrank();
    }

    function test_Workflow_Swap_Yield() public {
        vm.startPrank(user);

        // Setup: User has 100 USDT
        usdt.mint(user, 100 * 1e18);
        usdt.approve(address(controller), 100 * 1e18);

        // Define Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            2
        );

        // Action 1: Swap USDT -> IDRX
        // swapWithProvider(adapter, tokenIn, tokenOut, amountIn, minAmountOut, to)
        // Note: amountIn in encoded data is ignored by Controller logic (it uses percentage),
        // but we must provide a placeholder.
        bytes memory swapData = abi.encode(
            address(testSwapAdapter),
            address(usdt),
            address(idrx),
            0, // placeholder amount
            0, // minAmountOut
            address(0) // to: address(0) means keep in Controller
        );

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000 // 100%
        });

        // Action 2: Yield Deposit IDRX
        // deposit(adapter, token, amount, data)
        bytes memory yieldData = abi.encode(
            address(testYieldAdapter),
            address(idrx),
            0, // placeholder amount
            "" // adapter data
        );

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: yieldData,
            inputAmountPercentage: 10000 // 100%
        });

        // Execute
        controller.executeWorkflow(actions, address(usdt), 100 * 1e18);

        // Verify:
        // 1. Controller should have 0 USDT (swapped)
        assertEq(usdt.balanceOf(address(controller)), 0);
        // 2. Controller should have 0 IDRX (deposited)
        assertEq(idrx.balanceOf(address(controller)), 0);
        // 3. TestYieldAdapter should hold the IDRX
        assertEq(idrx.balanceOf(address(testYieldAdapter)), 100 * 1e18);

        vm.stopPrank();
    }

    function test_Workflow_Transfer() public {
        vm.startPrank(user);

        usdt.mint(user, 100 * 1e18);
        usdt.approve(address(controller), 100 * 1e18);

        IMainController.Action[] memory actions = new IMainController.Action[](
            1
        );

        // Transfer 50% to user
        bytes memory transferData = abi.encode(address(usdt));

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user,
            data: transferData,
            inputAmountPercentage: 5000 // 50%
        });

        controller.executeWorkflow(actions, address(usdt), 100 * 1e18);

        // Verify:
        // Controller has 50
        assertEq(usdt.balanceOf(address(controller)), 50 * 1e18);
        // User has 50 (received back)
        assertEq(usdt.balanceOf(user), 50 * 1e18);

        vm.stopPrank();
    }

    function test_ExecuteWorkflow_Mint() public {
        vm.startPrank(user);

        // 1. Define Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            2
        );

        // Action 1: Mint IDRX
        // mint(token, amount)
        bytes memory mintData = abi.encode(address(idrx), 1000 * 1e18);

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(idrx), // Target is the token itself
            data: mintData,
            inputAmountPercentage: 0 // Ignored for MINT
        });

        // Action 2: Yield Deposit IDRX (using 100% of balance)
        bytes memory yieldData = abi.encode(
            address(testYieldAdapter),
            address(idrx),
            0,
            ""
        );

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: yieldData,
            inputAmountPercentage: 10000 // 100% of CURRENT balance
        });

        // 2. Execute Workflow
        // initialAmount is 0 because we are starting from scratch (minting first)
        controller.executeWorkflow(actions, address(0), 0);

        // 3. Verify
        // Controller should have 0 IDRX (deposited)
        assertEq(idrx.balanceOf(address(controller)), 0);
        // TestYieldAdapter should hold the IDRX
        assertEq(idrx.balanceOf(address(testYieldAdapter)), 1000 * 1e18);

        vm.stopPrank();
    }
}
