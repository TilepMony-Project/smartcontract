// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IMainController} from "../src/interfaces/IMainController.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockIDRXCrossChain} from "../src/token/MockIDRXCrossChain.sol";

// Interfaces for interaction
interface IMockToken is IERC20 {
    function decimals() external view returns (uint8);
}

contract ForkSimulation is Test {
    // Real Addresses from contractConfig.ts
    address constant MAIN_CONTROLLER =
        0x2933CbFE50b8e0060feeDd192a4C0F356063EB98;
    address constant SWAP_AGGREGATOR =
        0xed47849Eb9548F164234287964356eF9A6f73075;
    address constant IDRX = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
    address constant USDT = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;
    address constant USDC = 0x681db03Ef13e37151e9fd68920d2c34273194379;

    // Adapters
    address constant FUSIONX_ADAPTER =
        0x864d3a6F4804ABd32D7b42414E33Ed1CAeC5F505;

    // User / Recipient
    address user = address(0x1234);
    address recipient = 0xA3e8a25D6A7d22c47CFd9e23490A5b1bbD659673; // User's specific recipient

    IMainController controller = IMainController(MAIN_CONTROLLER);

    function setUp() public {
        // Forking will be handled via CLI args: --fork-url ...
    }

    function test_Fork_MintSwapTransfer() public {
        vm.createSelectFork("https://rpc.sepolia.mantle.xyz"); // Latest block

        // Start Prank
        vm.startPrank(user);

        // 1. Setup Actions
        IMainController.Action[] memory actions = new IMainController.Action[](
            3
        );

        // Action 0: MINT IDRX
        // IMPORTANT: Verify Decimals. IDRX should be 6.
        uint8 idrxDecimals = MockIDRXCrossChain(IDRX).decimals();
        console.log("IDRX Decimals:", idrxDecimals);
        uint8 usdcDecimals = MockIDRXCrossChain(USDC).decimals();
        console.log("USDC Decimals:", usdcDecimals);

        uint256 mintAmount = 100 * (10 ** idrxDecimals); // 100 IDRX
        console.log("1. Minting Amount (IDRX):", mintAmount);
        bytes memory mintData = abi.encode(IDRX, mintAmount);

        actions[0] = IMainController.Action({
            actionType: IMainController.ActionType.MINT,
            targetContract: IDRX,
            data: mintData,
            inputAmountPercentage: 0
        });

        // Action 1: SWAP IDRX -> USDC (User mentioned USDC in screenshot, or Swap to something)
        // Let's assume Swap to USDC based on screenshot "Token to Transfer: USDC"
        address tokenOut = USDC;
        bytes memory swapData = abi.encode(
            FUSIONX_ADAPTER,
            IDRX,
            tokenOut,
            0, // amountIn 0 (placeholder)
            0, // minAmountOut
            address(0) // to address(0) for MainController
        );

        actions[1] = IMainController.Action({
            actionType: IMainController.ActionType.SWAP,
            targetContract: SWAP_AGGREGATOR,
            data: swapData,
            inputAmountPercentage: 10000 // 100%
        });

        // Action 2: TRANSFER USDC
        bytes memory transferData = abi.encode(tokenOut);
        actions[2] = IMainController.Action({
            actionType: IMainController.ActionType.TRANSFER,
            targetContract: recipient,
            data: transferData,
            inputAmountPercentage: 10000 // 100%
        });

        // 2. Execute Workflow
        // Source = MINT, so initialAmount = 0
        try controller.executeWorkflow(actions, address(0), 0) {
            console.log("Workflow Executed Successfully!");
        } catch Error(string memory reason) {
            console.log("Reverted with reason:", reason);
            fail();
        } catch (bytes memory lowLevelData) {
            console.logBytes(lowLevelData);
            fail();
        }
        // 3. Verify & Log Results
        uint256 finalUsdcBalance = IERC20(USDC).balanceOf(recipient);
        console.log("2. Swap Result (USDC):", finalUsdcBalance);
        console.log("3. Transferred Amount (USDC):", finalUsdcBalance);
        vm.stopPrank();
    }
}
