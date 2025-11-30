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

contract SwapScript is Script {
    FusionXRouter public fusionXRouter;
    MerchantMoeRouter public merchantMoeRouter;
    VertexRouter public vertexRouter;
    FusionXAdapter public fusionXAdapter;
    MerchantMoeAdapter public merchantMoeAdapter;
    VertexAdapter public vertexAdapter;
    SwapAggregator public swapAggregator;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        fusionXRouter = new FusionXRouter();
        fusionXAdapter = new FusionXAdapter(address(fusionXRouter));

        console.log("FusionX router deployed at:", address(fusionXRouter));
        console.log("FusionX adapter deployed at:", address(fusionXAdapter));

        merchantMoeRouter = new MerchantMoeRouter();
        merchantMoeAdapter = new MerchantMoeAdapter(address(merchantMoeRouter));

        console.log("MerchantMoe router deployed at:", address(merchantMoeRouter));
        console.log("MerchantMoe adapter deployed at:", address(merchantMoeAdapter));

        vertexRouter = new VertexRouter();
        vertexAdapter = new VertexAdapter(address(vertexRouter));

        console.log("Vertex router deployed at:", address(vertexRouter));
        console.log("Vertex adapter deployed at:", address(vertexAdapter));

        swapAggregator = new SwapAggregator();
        swapAggregator.addTrustedAdapter(address(fusionXAdapter));
        swapAggregator.addTrustedAdapter(address(merchantMoeAdapter));
        swapAggregator.addTrustedAdapter(address(vertexAdapter));

        console.log("Swap aggregator deployed at:", address(swapAggregator));

        vm.stopBroadcast();
    }
}
