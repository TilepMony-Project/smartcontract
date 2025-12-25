// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {TokenHypERC20} from "../src/token/TokenHypERC20.sol";
import {FusionXAdapter} from "../src/swap/adapters/FusionXAdapter.sol";
import {MerchantMoeAdapter} from "../src/swap/adapters/MerchantMoeAdapter.sol";
import {VertexAdapter} from "../src/swap/adapters/VertexAdapter.sol";

contract AddLiquidity is Script {
    uint256 internal constant AMOUNT_USD = 1_000_000 * 1e6;
    uint256 internal constant AMOUNT_IDRX = 10_000_000_000 * 1e6;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address fusionXAdapter = vm.envAddress("FUSIONX_ADAPTER");
        address merchantMoeAdapter = vm.envAddress("MERCHANT_MOE_ADAPTER");
        address vertexAdapter = vm.envAddress("VERTEX_ADAPTER");
        address idrx = vm.envAddress("IDRX_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");

        _requireNonZero(fusionXAdapter, "FUSIONX_ADAPTER");
        _requireNonZero(merchantMoeAdapter, "MERCHANT_MOE_ADAPTER");
        _requireNonZero(vertexAdapter, "VERTEX_ADAPTER");
        _requireNonZero(idrx, "IDRX_ADDRESS");
        _requireNonZero(usdc, "USDC_ADDRESS");
        _requireNonZero(usdt, "USDT_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Adapters:", fusionXAdapter, merchantMoeAdapter, vertexAdapter);
        console.log("Tokens:", idrx, usdc, usdt);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Get Router Addresses dynamically
        address fusionXRouter = address(FusionXAdapter(fusionXAdapter).ROUTER());
        address merchantMoeRouter = address(MerchantMoeAdapter(merchantMoeAdapter).ROUTER());
        address vertexRouter = address(VertexAdapter(vertexAdapter).ROUTER());

        address[3] memory routers = [fusionXRouter, merchantMoeRouter, vertexRouter];
        string[3] memory names = ["FusionX", "MerchantMoe", "Vertex"];

        // 2. Add Liquidity to ALL Routers
        for (uint256 i = 0; i < 3; i++) {
            address router = routers[i];
            string memory name = names[i];
            console.log("Adding liquidity to", name, "Router:", router);

            // USDC
            TokenHypERC20(usdc).giveMe(AMOUNT_USD);
            require(TokenHypERC20(usdc).transfer(router, AMOUNT_USD), "USDC Transfer failed");

            // USDT
            TokenHypERC20(usdt).giveMe(AMOUNT_USD);
            require(TokenHypERC20(usdt).transfer(router, AMOUNT_USD), "USDT Transfer failed");

            // IDRX
            TokenHypERC20(idrx).giveMe(AMOUNT_IDRX);
            require(TokenHypERC20(idrx).transfer(router, AMOUNT_IDRX), "IDRX Transfer failed");
        }

        console.log("Liquidity Added to ALL Routers!");
        vm.stopBroadcast();
    }

    function _requireNonZero(address a, string memory label) internal pure {
        require(a != address(0), label);
    }
}
