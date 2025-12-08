// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CheckRouterBalance is Script {
    // Routers
    address constant FUSIONX_ROUTER =
        0x05047114AD8De5E3dc3006F2f8468F0a31C46395;
    address constant MERCHANT_MOE_ROUTER =
        0xa192eE8a20e8DD17a478d7A0F0A72cd5502db19d;
    address constant VERTEX_ROUTER = 0xd64dADee7A042e96aa61514502C5545922627A26;

    // Tokens
    address constant IDRX = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
    address constant USDC = 0x681db03Ef13e37151e9fd68920d2c34273194379;
    address constant USDT = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

    function run() public view {
        address[3] memory routers = [
            FUSIONX_ROUTER,
            MERCHANT_MOE_ROUTER,
            VERTEX_ROUTER
        ];
        string[3] memory names = ["FusionX", "MerchantMoe", "Vertex"];

        for (uint i = 0; i < 3; i++) {
            address router = routers[i];
            string memory name = names[i];
            console.log("\n--- Checking", name, "Router ---");
            console.log("Address:", router);

            uint256 balIDRX = IERC20(IDRX).balanceOf(router);
            uint256 balUSDC = IERC20(USDC).balanceOf(router);
            uint256 balUSDT = IERC20(USDT).balanceOf(router);

            console.log("IDRX Balance:", balIDRX);
            console.log("USDC Balance:", balUSDC);
            console.log("USDT Balance:", balUSDT);
        }
    }
}
