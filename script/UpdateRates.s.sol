// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ISwapRouter} from "../src/swap/interfaces/ISwapRouter.sol";

contract UpdateRates is Script {
    // Routers (From your recent logs)
    address constant FUSIONX_ROUTER =
        0x05047114AD8De5E3dc3006F2f8468F0a31C46395;
    address constant MERCHANT_MOE_ROUTER =
        0xa192eE8a20e8DD17a478d7A0F0A72cd5502db19d;
    address constant VERTEX_ROUTER = 0xd64dADee7A042e96aa61514502C5545922627A26;

    // NEW Token Addresses (mTokens)
    address constant mIDRX = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
    address constant mUSDC = 0x681db03Ef13e37151e9fd68920d2c34273194379;
    address constant mUSDT = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256 one = 1e18;
        uint256 usdIdr = 16500e18;
        uint256 idrUsd = (1e18 * 1e18) / usdIdr; // Invert

        console.log("Updating Rates for mTokens...");

        // 1. FusionX
        ISwapRouter(FUSIONX_ROUTER).setRate(mIDRX, mUSDC, idrUsd);
        ISwapRouter(FUSIONX_ROUTER).setRate(mUSDC, mIDRX, usdIdr);
        ISwapRouter(FUSIONX_ROUTER).setRate(mIDRX, mUSDT, idrUsd);
        ISwapRouter(FUSIONX_ROUTER).setRate(mUSDT, mIDRX, usdIdr);
        ISwapRouter(FUSIONX_ROUTER).setRate(mUSDC, mUSDT, one);
        ISwapRouter(FUSIONX_ROUTER).setRate(mUSDT, mUSDC, one);
        console.log("FusionX Rates Updated");

        // 2. MerchantMoe
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mIDRX, mUSDC, idrUsd);
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mUSDC, mIDRX, usdIdr);
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mIDRX, mUSDT, idrUsd);
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mUSDT, mIDRX, usdIdr);
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mUSDC, mUSDT, one);
        ISwapRouter(MERCHANT_MOE_ROUTER).setRate(mUSDT, mUSDC, one);
        console.log("MerchantMoe Rates Updated");

        // 3. Vertex (Stable-Stable)
        ISwapRouter(VERTEX_ROUTER).setRate(mUSDC, mUSDT, one);
        ISwapRouter(VERTEX_ROUTER).setRate(mUSDT, mUSDC, one);
        ISwapRouter(VERTEX_ROUTER).setRate(mIDRX, mUSDC, idrUsd);
        ISwapRouter(VERTEX_ROUTER).setRate(mUSDC, mIDRX, usdIdr);
        ISwapRouter(VERTEX_ROUTER).setRate(mIDRX, mUSDT, idrUsd);
        ISwapRouter(VERTEX_ROUTER).setRate(mUSDT, mIDRX, usdIdr);
        console.log("Vertex Rates Updated");

        vm.stopBroadcast();
    }
}
