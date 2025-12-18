// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {FusionXRouter} from "../src/swap/routers/FusionXRouter.sol";
import {MerchantMoeRouter} from "../src/swap/routers/MerchantMoeRouter.sol";
import {VertexRouter} from "../src/swap/routers/VertexRouter.sol";
import {FusionXAdapter} from "../src/swap/adapters/FusionXAdapter.sol";
import {MerchantMoeAdapter} from "../src/swap/adapters/MerchantMoeAdapter.sol";
import {VertexAdapter} from "../src/swap/adapters/VertexAdapter.sol";
import {SwapAggregator} from "../src/swap/SwapAggregator.sol";
import {ISwapRouter} from "../src/swap/interfaces/ISwapRouter.sol";

contract SwapScript is Script {
    FusionXRouter public fusionXRouter;
    MerchantMoeRouter public merchantMoeRouter;
    VertexRouter public vertexRouter;
    FusionXAdapter public fusionXAdapter;
    MerchantMoeAdapter public merchantMoeAdapter;
    VertexAdapter public vertexAdapter;
    SwapAggregator public swapAggregator;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address idrx = vm.envAddress("IDRX_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Routers
        fusionXRouter = new FusionXRouter();
        merchantMoeRouter = new MerchantMoeRouter();
        vertexRouter = new VertexRouter();

        console.log("FusionX router deployed at:", address(fusionXRouter));
        console.log("MerchantMoe router deployed at:", address(merchantMoeRouter));
        console.log("Vertex router deployed at:", address(vertexRouter));

        // 2. Set Initial Rates (1:1 for stablecoins)
        uint256 one = 1e18; // 1e18 precision
        uint256 usdIdr = 16500e18;
        uint256 idrUsd = (1e18 * 1e18) / usdIdr; // Invert

        _setPairRate(address(fusionXRouter), idrx, usdc, idrUsd);
        _setPairRate(address(fusionXRouter), usdc, idrx, usdIdr);
        _setPairRate(address(fusionXRouter), idrx, usdt, idrUsd);
        _setPairRate(address(fusionXRouter), usdt, idrx, usdIdr);

        _setPairRate(address(merchantMoeRouter), idrx, usdc, idrUsd);
        _setPairRate(address(merchantMoeRouter), usdc, idrx, usdIdr);

        _setPairRate(address(vertexRouter), usdc, usdt, one);
        _setPairRate(address(vertexRouter), usdt, usdc, one);

        // 3. Deploy Adapters
        fusionXAdapter = new FusionXAdapter(address(fusionXRouter));
        merchantMoeAdapter = new MerchantMoeAdapter(address(merchantMoeRouter));
        vertexAdapter = new VertexAdapter(address(vertexRouter));

        console.log("FusionX adapter deployed at:", address(fusionXAdapter));
        console.log("MerchantMoe adapter deployed at:", address(merchantMoeAdapter));
        console.log("Vertex adapter deployed at:", address(vertexAdapter));

        // 4. Deploy Aggregator & Whitelist Adapters
        swapAggregator = new SwapAggregator();
        swapAggregator.addTrustedAdapter(address(fusionXAdapter));
        swapAggregator.addTrustedAdapter(address(merchantMoeAdapter));
        swapAggregator.addTrustedAdapter(address(vertexAdapter));

        console.log("Swap aggregator deployed at:", address(swapAggregator));

        vm.stopBroadcast();
    }

    function _setPairRate(address router, address tokenIn, address tokenOut, uint256 rate) internal {
        // Use the common interface to set rates
        ISwapRouter(router).setRate(tokenIn, tokenOut, rate);
    }
}
