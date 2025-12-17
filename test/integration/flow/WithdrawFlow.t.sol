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

contract WithdrawFlowIntegrationTest is Test {
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

    function setUp() public {
        vm.startPrank(user);

        // 1. Deploy Tokens
        usdt = new MockUSDTCrossChain();
        idrx = new MockIDRXCrossChain();

        // 2. Deploy Aggregators
        swapAggregator = new SwapAggregator();
        yieldRouter = new YieldRouter();

        // 3. Deploy Swap System
        fusionXRouter = new FusionXRouter();
        fusionXAdapter = new FusionXAdapter(address(fusionXRouter));
        fusionXRouter.setRate(address(usdt), address(idrx), 16500 * 1e18);

        // 4. Deploy Yield System (Compound)
        mockComet = new MockComet(address(idrx), "Compound Mock", "cMOCK");
        compoundAdapter = new CompoundAdapter(address(mockComet));

        // 5. Whitelist Adapters
        swapAggregator.addTrustedAdapter(address(fusionXAdapter));
        yieldRouter.setAdapterWhitelist(address(compoundAdapter), true);

        // 6. Deploy Controller
        controller = new MainController(user);

        // 7. Liquidity
        idrx.giveMe(10_000_000 * 1e6);
        bool success = idrx.transfer(address(fusionXRouter), 10_000_000 * 1e6);
        require(success, "Transfer failed");

        vm.stopPrank();
    }

    function test_Flow_Withdraw() public {
        vm.startPrank(user);

        console.log("--- Phase 1: Deposit Flow (Mint -> Swap -> Yield) ---");

        // Prepare Deposit Actions
        IMainController.Action[] memory depositActions = new IMainController.Action[](4);

        // Action 1: Mint 100 USDT
        uint256 mintAmount = 100 * 1e6;
        depositActions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: abi.encode(address(usdt), mintAmount),
            inputAmountPercentage: 0
        });

        // Action 2: Swap USDT -> IDRX
        depositActions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: abi.encode(address(fusionXAdapter), address(usdt), address(idrx), 0, 0, address(0)),
            inputAmountPercentage: 10000
        });

        // Action 3: Yield Deposit IDRX
        depositActions[2] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: abi.encode(address(compoundAdapter), address(idrx), 0, ""),
            inputAmountPercentage: 10000
        });

        // Action 4: Transfer Shares to User (so User can withdraw later)
        depositActions[3] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user,
            data: abi.encode(address(mockComet)),
            inputAmountPercentage: 10000
        });

        controller.executeWorkflow(depositActions, address(0), 0);

        // Verify Deposit Success (User holds shares)
        uint256 userShares = mockComet.balanceOf(user);
        uint256 expectedShares = 1650000 * 1e6;
        assertEq(userShares, expectedShares, "User should have shares after deposit");
        console.log("User Shares (Before Withdraw):", userShares);

        console.log("--- Phase 2: Withdraw Flow ---");

        // Action: User approves Controller to spend Shares
        mockComet.approve(address(controller), userShares);

        // Prepare Withdraw Actions
        IMainController.Action[] memory withdrawActions = new IMainController.Action[](1);

        // Action 1: YIELD_WITHDRAW
        // Need to encode: (adapter, shareToken, underlyingToken, placeholderAmount, adapterData)
        bytes memory withdrawData = abi.encode(
            address(compoundAdapter),
            address(mockComet), // Share Token
            address(idrx), // Underlying Token
            0, // Placeholder amount
            "" // Adapter Data
        );

        withdrawActions[0] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD_WITHDRAW,
            targetContract: address(yieldRouter),
            data: withdrawData,
            inputAmountPercentage: 5000 // Withdraw 50%
        });

        // Execute Withdraw
        // initialToken=0 because we are pulling from User, not sending initial funds
        controller.executeWorkflow(withdrawActions, address(0), 0);

        // Verify Withdrawal
        uint256 userSharesAfter = mockComet.balanceOf(user);

        // Let's check Controller balance first.
        uint256 controllerIdrx = idrx.balanceOf(address(controller));

        console.log("User Shares (After Withdraw):", userSharesAfter);
        console.log("Controller IDRX (After Withdraw):", controllerIdrx);

        // We withdrew 50% -> 825,000 shares burned.
        assertEq(userSharesAfter, expectedShares / 2, "User should have 50% shares remaining");

        // Controller should hold the redeemed IDRX
        assertEq(controllerIdrx, 825000 * 1e6, "Controller should hold redeemed IDRX");

        vm.stopPrank();
    }
}
