// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MainController} from "../../../src/core/MainController.sol";
import {IMainController} from "../../../src/interfaces/IMainController.sol";
import {SwapAggregator} from "../../../src/swap/SwapAggregator.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";
import {MockUSDTCrossChain} from "../../../src/token/MockUSDTCrossChain.sol";
import {MockIDRXCrossChain} from "../../../src/token/MockIDRXCrossChain.sol";
import {FusionXRouter} from "../../../src/swap/routers/FusionXRouter.sol";
import {FusionXAdapter} from "../../../src/swap/adapters/FusionXAdapter.sol";
import {MockComet} from "../../../src/yield/mocks/MockComet.sol";
import {CompoundAdapter} from "../../../src/yield/adapters/CompoundAdapter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FlowIntegrationTest is Test {
    MainController controller;
    SwapAggregator swapAggregator;
    YieldRouter yieldRouter;

    MockUSDTCrossChain usdt;
    MockIDRXCrossChain idrx;

    FusionXRouter fusionXRouter;
    FusionXAdapter fusionXAdapter;

    MockComet mockComet;
    CompoundAdapter compoundAdapter;

    address user = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
        vm.startPrank(user);

        // 1. Deploy Tokens
        usdt = new MockUSDTCrossChain();
        idrx = new MockIDRXCrossChain();

        // 2. Deploy Aggregators
        swapAggregator = new SwapAggregator();
        yieldRouter = new YieldRouter();

        // 3. Deploy FusionX System (Swap)
        fusionXRouter = new FusionXRouter();
        fusionXAdapter = new FusionXAdapter(address(fusionXRouter));

        // Set Rate: 1 USDT = 16500 IDRX
        // USDT decimals = 6, IDRX decimals = 6
        // Rate = 16500
        fusionXRouter.setRate(address(usdt), address(idrx), 16500);

        // 4. Deploy Compound System (Yield)
        // Base token for Comet is IDRX (since we swap to IDRX then deposit)
        mockComet = new MockComet(address(idrx));
        compoundAdapter = new CompoundAdapter(address(mockComet));

        // 5. Whitelist Adapters
        swapAggregator.addTrustedAdapter(address(fusionXAdapter));
        yieldRouter.setAdapterWhitelist(address(compoundAdapter), true);

        // 6. Deploy Controller
        controller = new MainController(user);

        // 7. Provide Liquidity to FusionXRouter
        // The router needs IDRX to send back to the user during the swap
        idrx.giveMe(10_000_000 * 1e6); // Mint to self (user) first
        idrx.transfer(address(fusionXRouter), 10_000_000 * 1e6); // Transfer to router

        vm.stopPrank();
    }

    function test_Flow_Mint_Swap_Transfer() public {
        vm.startPrank(user);

        console.log("--- Start: Mint -> Swap -> Transfer ---");
        console.log("Initial User USDT Balance:", usdt.balanceOf(user));
        console.log("Initial User IDRX Balance:", idrx.balanceOf(user));

        // Define Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            2
        );

        // Action 1: Mint USDT
        // mint(token, amount)
        // Mint 100 USDT (6 decimals)
        uint256 mintAmount = 100 * 1e6;
        bytes memory mintData = abi.encode(address(usdt), mintAmount);

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: mintData,
            inputAmountPercentage: 0 // Ignored for MINT
        });

        // Action 2: Swap USDT -> IDRX
        // swapWithProvider(adapter, tokenIn, tokenOut, amountIn, minAmountOut, to)
        // We want to swap 100% of the minted USDT
        // Expected Output: 100 * 16500 = 1,650,000 IDRX
        bytes memory swapData = abi.encode(
            address(fusionXAdapter),
            address(usdt),
            address(idrx),
            0, // placeholder amount
            0, // minAmountOut
            address(0) // to: address(0) means keep in Controller
        );

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000 // 100%
        });

        // We need a 3rd action to Transfer to User2, but let's try chaining 3 actions
        // Re-defining actions array to size 3
        IMainController.Action[] memory actions3 = new IMainController.Action[](
            3
        );
        actions3[0] = actions[0];
        actions3[1] = actions[1];

        // Action 3: Transfer IDRX to User2
        bytes memory transferData = abi.encode(address(idrx));

        actions3[2] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user2,
            data: transferData,
            inputAmountPercentage: 10000 // 100% of IDRX balance
        });

        console.log("Executing Workflow...");
        // Execute Workflow
        controller.executeWorkflow(actions3, address(0), 0);

        // Verify:
        uint256 controllerUsdt = usdt.balanceOf(address(controller));
        uint256 controllerIdrx = idrx.balanceOf(address(controller));
        uint256 user2Idrx = idrx.balanceOf(user2);

        console.log("--- End State ---");
        console.log("Controller USDT Balance:", controllerUsdt);
        console.log("Controller IDRX Balance:", controllerIdrx);
        console.log("User2 IDRX Balance:     ", user2Idrx);

        // 1. Controller should have 0 USDT
        assertEq(controllerUsdt, 0, "Controller should have 0 USDT");
        // 2. Controller should have 0 IDRX
        assertEq(controllerIdrx, 0, "Controller should have 0 IDRX");
        // 3. User2 should have 1,650,000 IDRX
        uint256 expectedIdrx = 1650000 * 1e6;
        console.log("Expected User2 IDRX:    ", expectedIdrx);
        assertEq(
            user2Idrx,
            expectedIdrx,
            "User2 should have correct IDRX amount"
        );

        vm.stopPrank();
    }

    function test_Flow_Mint_Swap_Yield() public {
        vm.startPrank(user);

        console.log("--- Start: Mint -> Swap -> Yield ---");
        console.log("Initial User USDT Balance:", usdt.balanceOf(user));
        console.log(
            "Initial MockComet IDRX Balance:",
            idrx.balanceOf(address(mockComet))
        );

        IMainController.Action[] memory actions = new IMainController.Action[](
            3
        );

        // Action 1: Mint USDT
        uint256 mintAmount = 100 * 1e6;
        bytes memory mintData = abi.encode(address(usdt), mintAmount);

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: mintData,
            inputAmountPercentage: 0
        });

        // Action 2: Swap USDT -> IDRX
        bytes memory swapData = abi.encode(
            address(fusionXAdapter),
            address(usdt),
            address(idrx),
            0,
            0,
            address(0)
        );

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000
        });

        // Action 3: Yield Deposit IDRX into Compound
        // deposit(adapter, token, amount, data)
        bytes memory yieldData = abi.encode(
            address(compoundAdapter),
            address(idrx),
            0, // placeholder amount
            "" // adapter data
        );

        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: yieldData,
            inputAmountPercentage: 10000 // 100% of IDRX balance
        });

        console.log("Executing Workflow...");
        // Execute Workflow
        controller.executeWorkflow(actions, address(0), 0);

        // Verify:
        uint256 controllerUsdt = usdt.balanceOf(address(controller));
        uint256 controllerIdrx = idrx.balanceOf(address(controller));
        uint256 cometIdrx = idrx.balanceOf(address(mockComet));

        console.log("--- End State ---");
        console.log("Controller USDT Balance:", controllerUsdt);
        console.log("Controller IDRX Balance:", controllerIdrx);
        console.log("MockComet IDRX Balance: ", cometIdrx);

        // 1. Controller should have 0 USDT
        assertEq(controllerUsdt, 0, "Controller should have 0 USDT");
        // 2. Controller should have 0 IDRX
        assertEq(controllerIdrx, 0, "Controller should have 0 IDRX");
        // 3. MockComet should hold the IDRX (since CompoundAdapter supplies it there)
        uint256 expectedCometIdrx = 1650000 * 1e6;
        console.log("Expected MockComet IDRX:", expectedCometIdrx);
        assertEq(cometIdrx, expectedCometIdrx, "MockComet should hold IDRX");

        vm.stopPrank();
    }
}
