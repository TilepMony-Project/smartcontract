// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ISwapRouter} from "../src/swap/interfaces/ISwapRouter.sol";

contract UpdateRates is Script {
    function _envAddress(string memory key) internal view returns (address) {
        return vm.envAddress(key);
    }

    function _envString(string memory key, string memory fallback) internal view returns (string memory) {
        return vm.envOr(key, fallback);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory chainProfile = _envString("SWAP_CHAIN", "BASE");
        bool isMantle = keccak256(bytes(chainProfile)) == keccak256("MANTLE");

        address fusionXRouter = _envAddress(isMantle ? "FUSIONX_ROUTER_MANTLE" : "FUSIONX_ROUTER_BASE");
        address merchantMoeRouter = _envAddress(isMantle ? "MERCHANT_MOE_ROUTER_MANTLE" : "MERCHANT_MOE_ROUTER_BASE");
        address vertexRouter = _envAddress(isMantle ? "VERTEX_ROUTER_MANTLE" : "VERTEX_ROUTER_BASE");

        address idrx = _envAddress(isMantle ? "MANTLE_IDRX_ADDRESS" : "BASE_IDRX_ADDRESS");
        address usdc = _envAddress(isMantle ? "MANTLE_USDC_ADDRESS" : "BASE_USDC_ADDRESS");
        address usdt = _envAddress(isMantle ? "MANTLE_USDT_ADDRESS" : "BASE_USDT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        uint256 one = 1e18;
        uint256 usdIdr = 16500e18;
        uint256 idrUsd = (1e18 * 1e18) / usdIdr; // Invert

        console.log("Updating Rates for mTokens...");
        console.log("Chain profile:", chainProfile);
        console.log("FusionX router:", fusionXRouter);
        console.log("MerchantMoe router:", merchantMoeRouter);
        console.log("Vertex router:", vertexRouter);
        console.log("IDRX:", idrx);
        console.log("USDC:", usdc);
        console.log("USDT:", usdt);

        // 1. FusionX
        ISwapRouter(fusionXRouter).setRate(idrx, usdc, idrUsd);
        ISwapRouter(fusionXRouter).setRate(usdc, idrx, usdIdr);
        ISwapRouter(fusionXRouter).setRate(idrx, usdt, idrUsd);
        ISwapRouter(fusionXRouter).setRate(usdt, idrx, usdIdr);
        ISwapRouter(fusionXRouter).setRate(usdc, usdt, one);
        ISwapRouter(fusionXRouter).setRate(usdt, usdc, one);
        console.log("FusionX Rates Updated");

        // 2. MerchantMoe
        ISwapRouter(merchantMoeRouter).setRate(idrx, usdc, idrUsd);
        ISwapRouter(merchantMoeRouter).setRate(usdc, idrx, usdIdr);
        ISwapRouter(merchantMoeRouter).setRate(idrx, usdt, idrUsd);
        ISwapRouter(merchantMoeRouter).setRate(usdt, idrx, usdIdr);
        ISwapRouter(merchantMoeRouter).setRate(usdc, usdt, one);
        ISwapRouter(merchantMoeRouter).setRate(usdt, usdc, one);
        console.log("MerchantMoe Rates Updated");

        // 3. Vertex (Stable-Stable)
        ISwapRouter(vertexRouter).setRate(usdc, usdt, one);
        ISwapRouter(vertexRouter).setRate(usdt, usdc, one);
        ISwapRouter(vertexRouter).setRate(idrx, usdc, idrUsd);
        ISwapRouter(vertexRouter).setRate(usdc, idrx, usdIdr);
        ISwapRouter(vertexRouter).setRate(idrx, usdt, idrUsd);
        ISwapRouter(vertexRouter).setRate(usdt, idrx, usdIdr);
        console.log("Vertex Rates Updated");

        vm.stopBroadcast();
    }
}
