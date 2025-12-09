// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MockIDRXCrossChain} from "../src/token/MockIDRXCrossChain.sol";
import {FusionXAdapter} from "../src/swap/adapters/FusionXAdapter.sol";
import {MerchantMoeAdapter} from "../src/swap/adapters/MerchantMoeAdapter.sol";
import {VertexAdapter} from "../src/swap/adapters/VertexAdapter.sol";

contract AddLiquidity is Script {
    // Adapter Addresses from contractConfig.ts
    address constant FUSIONX_ADAPTER =
        0x864d3a6F4804ABd32D7b42414E33Ed1CAeC5F505;
    address constant MERCHANT_MOE_ADAPTER =
        0xA80e0Cc68389D3e98Fd41887e70580d5D260f022;
    address constant VERTEX_ADAPTER =
        0x20e7f518Bf77cde999Dba30758F7C562Db0b5A9C;

    // Tokens
    address constant IDRX = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
    address constant USDC = 0x681db03Ef13e37151e9fd68920d2c34273194379;
    address constant USDT = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Get Router Addresses dynamically
        address fusionXRouter = address(
            FusionXAdapter(FUSIONX_ADAPTER).ROUTER()
        );
        address merchantMoeRouter = address(
            MerchantMoeAdapter(MERCHANT_MOE_ADAPTER).ROUTER()
        );
        address vertexRouter = address(VertexAdapter(VERTEX_ADAPTER).ROUTER());

        address[3] memory routers = [
            fusionXRouter,
            merchantMoeRouter,
            vertexRouter
        ];
        string[3] memory names = ["FusionX", "MerchantMoe", "Vertex"];

        // 2. Add Liquidity to ALL Routers
        for (uint i = 0; i < 3; i++) {
            address router = routers[i];
            string memory name = names[i];
            console.log("Adding liquidity to", name, "Router:", router);

            // USDC
            MockIDRXCrossChain(USDC).giveMe(1000000 * 1e6);
            require(
                MockIDRXCrossChain(USDC).transfer(router, 1000000 * 1e6),
                "USDC Transfer failed"
            );

            // USDT
            MockIDRXCrossChain(USDT).giveMe(1000000 * 1e6);
            require(
                MockIDRXCrossChain(USDT).transfer(router, 1000000 * 1e6),
                "USDT Transfer failed"
            );

            // IDRX
            MockIDRXCrossChain(IDRX).giveMe(10000000000 * 1e6);
            require(
                MockIDRXCrossChain(IDRX).transfer(router, 10000000000 * 1e6),
                "IDRX Transfer failed"
            );
        }

        console.log("Liquidity Added to ALL Routers!");
        vm.stopBroadcast();
    }
}
