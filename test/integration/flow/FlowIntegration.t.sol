// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MainController} from "../../../src/core/MainController.sol";
import {IMainController} from "../../../src/interfaces/IMainController.sol";
import {SwapAggregator} from "../../../src/swap/SwapAggregator.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";
import {TokenHypERC20} from "../../../src/token/TokenHypERC20.sol";
import {FusionXRouter} from "../../../src/swap/routers/FusionXRouter.sol";
import {FusionXAdapter} from "../../../src/swap/adapters/FusionXAdapter.sol";
import {MockComet} from "../../../src/yield/mocks/MockComet.sol";
import {CompoundAdapter} from "../../../src/yield/adapters/CompoundAdapter.sol";
import {MockMailbox, MockInterchainGasPaymaster, MockInterchainSecurityModule} from "../../../test/mocks/HyperlaneStubs.sol";

import {InitCapitalAdapter} from "../../../src/yield/adapters/InitCapitalAdapter.sol";
import {MockInitCore} from "../../../src/yield/mocks/initCore/MockInitCore.sol";
import {MockLendingPool} from "../../../src/yield/mocks/initCore/MockLendingPool.sol";

contract FlowIntegrationTest is Test {
    MainController controller;
    SwapAggregator swapAggregator;
    YieldRouter yieldRouter;

    TokenHypERC20 usdt;
    TokenHypERC20 idrx;

    FusionXRouter fusionXRouter;
    FusionXAdapter fusionXAdapter;

    MockComet mockComet;
    CompoundAdapter compoundAdapter;

    MockInitCore initCore;
    MockLendingPool lendingPool;
    InitCapitalAdapter initAdapter;

    address user = address(0x123);
    address user2 = address(0x456);

    MockMailbox mailbox;
    MockInterchainGasPaymaster igp;
    MockInterchainSecurityModule ism;

    function setUp() public {
        vm.startPrank(user);

        mailbox = new MockMailbox(1);
        igp = new MockInterchainGasPaymaster();
        ism = new MockInterchainSecurityModule();

        // 1. Deploy Tokens
        usdt = _deployToken("Mock USDT", "mUSDT");
        idrx = _deployToken("Mock IDRX", "mIDRX");

        // 2. Deploy Aggregators
        swapAggregator = new SwapAggregator();
        yieldRouter = new YieldRouter();

        // 3. Deploy FusionX System (Swap)
        fusionXRouter = new FusionXRouter();
        fusionXAdapter = new FusionXAdapter(address(fusionXRouter));

        // Set Rate: 1 USDT = 16500 IDRX
        // USDT decimals = 6, IDRX decimals = 6
        // Rate = 16500
        fusionXRouter.setRate(address(usdt), address(idrx), 16500 * 1e18);

        // 4. Deploy Compound System (Yield)
        mockComet = new MockComet(address(idrx), "Compound Mock", "cMOCK");
        compoundAdapter = new CompoundAdapter(address(mockComet));

        // 5. Deploy Init Capital System (Yield)
        initCore = new MockInitCore();
        // LendingPool needs to be for IDRX
        lendingPool = new MockLendingPool(address(idrx), "Init Yield IDRX", "inIDRX");
        initAdapter = new InitCapitalAdapter(address(initCore));
        initAdapter.setPool(address(idrx), address(lendingPool));

        // 6. Whitelist Adapters
        swapAggregator.addTrustedAdapter(address(fusionXAdapter));
        yieldRouter.setAdapterWhitelist(address(compoundAdapter), true);
        yieldRouter.setAdapterWhitelist(address(initAdapter), true);

        // 7. Deploy Controller
        controller = new MainController(user);

        // 8. Provide Liquidity to FusionXRouter
        idrx.giveMe(10_000_000 * 1e6);
        bool success = idrx.transfer(address(fusionXRouter), 10_000_000 * 1e6);
        require(success, "Transfer failed");

        vm.stopPrank();
    }

    function _deployToken(string memory name, string memory symbol) internal returns (TokenHypERC20) {
        return new TokenHypERC20(
            address(mailbox),
            6,
            name,
            symbol,
            address(igp),
            address(ism),
            user,
            0,
            address(this)
        );
    }

    function test_Flow_Mint_Swap_Transfer() public {
        vm.startPrank(user);

        console.log("--- Start: Mint -> Swap -> Transfer ---");

        IMainController.Action[] memory actions = new IMainController.Action[](3);

        // Action 1: Mint USDT
        uint256 mintAmount = 100 * 1e6;
        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: abi.encode(address(usdt), mintAmount),
            inputAmountPercentage: 0
        });

        // Action 2: Swap USDT -> IDRX
        // swapWithProvider(adapter, tokenIn, tokenOut, amountIn, minAmountOut, to)
        bytes memory swapData = abi.encode(address(fusionXAdapter), address(usdt), address(idrx), 0, 0, address(0));

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000
        });

        // Action 3: Transfer IDRX to User2
        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user2,
            data: abi.encode(address(idrx)),
            inputAmountPercentage: 10000
        });

        console.log("Executing Workflow...");
        controller.executeWorkflow(actions, address(0), 0);

        // Verify
        uint256 user2Idrx = idrx.balanceOf(user2);
        uint256 expectedIdrx = 1650000 * 1e6; // 100 * 16500

        assertEq(user2Idrx, expectedIdrx, "User2 should have correct IDRX amount");
        console.log("User2 IDRX Balance:", user2Idrx);

        vm.stopPrank();
    }

    function test_Flow_Mint_Swap_Yield_Transfer() public {
        vm.startPrank(user);

        console.log("--- Start: Mint -> Swap -> Yield (Compound) -> Transfer Shares ---");

        IMainController.Action[] memory actions = new IMainController.Action[](4);

        // Action 1: Mint USDT
        uint256 mintAmount = 100 * 1e6;
        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: abi.encode(address(usdt), mintAmount),
            inputAmountPercentage: 0
        });

        // Action 2: Swap USDT -> IDRX
        bytes memory swapData = abi.encode(address(fusionXAdapter), address(usdt), address(idrx), 0, 0, address(0));

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: swapData,
            inputAmountPercentage: 10000
        });

        // Action 3: Yield Deposit IDRX into Compound
        bytes memory yieldData = abi.encode(address(compoundAdapter), address(idrx), 0, "");

        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: yieldData,
            inputAmountPercentage: 10000
        });

        // Action 4: Transfer Shares (MockComet) to User2
        // Note: The share token for Compound is the Comet address itself
        actions[3] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user2,
            data: abi.encode(address(mockComet)), // Token to transfer is the Share Token
            inputAmountPercentage: 10000 // 100% of Shares
        });

        console.log("Executing Workflow...");
        controller.executeWorkflow(actions, address(0), 0);

        // Verify:
        // 1. MockComet should hold the IDRX
        uint256 expectedCometIdrx = 1650000 * 1e6;
        assertEq(idrx.balanceOf(address(mockComet)), expectedCometIdrx, "MockComet should hold underlying IDRX");

        // 2. User2 should hold the Shares (Comet Token)
        // MockComet mints 1:1, so User2 should have 1,650,000 * 1e6 cToken
        // Wait, MockComet mints 1:1.
        uint256 sharesUser2 = mockComet.balanceOf(user2);
        console.log("User2 Shares (Comet):", sharesUser2);

        // Assert shares
        assertEq(sharesUser2, expectedCometIdrx, "User2 should hold Compound Shares");

        // 3. Controller should have 0 shares
        assertEq(mockComet.balanceOf(address(controller)), 0, "Controller should have 0 Shares");

        vm.stopPrank();
    }

    function test_Flow_Mint_Swap_Init_Yield_Transfer() public {
        vm.startPrank(user);

        console.log("--- Start: Mint -> Swap -> Yield (InitCapital) -> Transfer Shares ---");

        IMainController.Action[] memory actions = new IMainController.Action[](4);

        // Action 1: Mint USDT
        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: address(usdt),
            data: abi.encode(address(usdt), 100 * 1e6),
            inputAmountPercentage: 0
        });

        // Action 2: Swap USDT -> IDRX
        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: address(swapAggregator),
            data: abi.encode(address(fusionXAdapter), address(usdt), address(idrx), 0, 0, address(0)),
            inputAmountPercentage: 10000
        });

        // Action 3: Yield Deposit IDRX into InitCapital
        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.YIELD,
            targetContract: address(yieldRouter),
            data: abi.encode(address(initAdapter), address(idrx), 0, ""),
            inputAmountPercentage: 10000
        });

        // Action 4: Transfer Shares (LendingPool Token) to User2
        // Share token for Init is the MockLendingPool
        actions[3] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: user2,
            data: abi.encode(address(lendingPool)), // Token to transfer is the Pool Token
            inputAmountPercentage: 10000
        });

        console.log("Executing Workflow...");
        controller.executeWorkflow(actions, address(0), 0);

        // Verify:
        // 1. MockLendingPool should hold the IDRX
        uint256 expectedIdrx = 1650000 * 1e6;
        assertEq(idrx.balanceOf(address(lendingPool)), expectedIdrx, "LendingPool should hold underlying IDRX");

        // 2. User2 should hold the Shares
        // MockInitCore currently hardcodes minting "100 ether" shares regardless of input.
        // Let's rely on that mock behavior for verification.
        uint256 sharesUser2 = lendingPool.balanceOf(user2);
        console.log("User2 Shares (Init Pool):", sharesUser2);

        assertEq(sharesUser2, expectedIdrx, "User2 should hold Init Shares (1:1 with Underlying)");

        vm.stopPrank();
    }
}
