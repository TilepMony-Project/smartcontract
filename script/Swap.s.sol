// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import "./Common.sol";
import {FusionXRouter} from "../src/swap/routers/FusionXRouter.sol";
import {MerchantMoeRouter} from "../src/swap/routers/MerchantMoeRouter.sol";
import {VertexRouter} from "../src/swap/routers/VertexRouter.sol";
import {FusionXAdapter} from "../src/swap/adapters/FusionXAdapter.sol";
import {MerchantMoeAdapter} from "../src/swap/adapters/MerchantMoeAdapter.sol";
import {VertexAdapter} from "../src/swap/adapters/VertexAdapter.sol";
import {SwapAggregator} from "../src/swap/SwapAggregator.sol";
import {ISwapRouter} from "../src/swap/interfaces/ISwapRouter.sol";

contract SwapScript is Script {
    address constant EIP2470_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

    FusionXRouter public fusionXRouter;
    MerchantMoeRouter public merchantMoeRouter;
    VertexRouter public vertexRouter;
    FusionXAdapter public fusionXAdapter;
    MerchantMoeAdapter public merchantMoeAdapter;
    VertexAdapter public vertexAdapter;
    SwapAggregator public swapAggregator;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("OWNER", vm.addr(deployerPrivateKey));
        address idrx = vm.envAddress("IDRX_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");

        string memory saltString = vm.envOr("SWAP_SALT_STRING", string("SWAP_STACK_V1"));
        bytes32 baseSalt = keccak256(bytes(saltString));

        string memory rpcUrl = vm.envOr("RPC_URL", string(""));
        console.log("RPC_URL:", bytes(rpcUrl).length == 0 ? "<not set>" : rpcUrl);
        console.log("SWAP_SALT_STRING:", saltString);
        console.logBytes32(baseSalt);
        console.log("Owner:", owner);
        console.log("IDRX:", idrx);
        console.log("USDC:", usdc);
        console.log("USDT:", usdt);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Routers
        address fusionXRouterAddr = _deployFusionXRouter(baseSalt, owner);
        address merchantMoeRouterAddr = _deployMerchantMoeRouter(baseSalt, owner);
        address vertexRouterAddr = _deployVertexRouter(baseSalt, owner);

        fusionXRouter = FusionXRouter(fusionXRouterAddr);
        merchantMoeRouter = MerchantMoeRouter(merchantMoeRouterAddr);
        vertexRouter = VertexRouter(vertexRouterAddr);

        // 2. Set Initial Rates (1:1 for stablecoins)
        uint256 one = 1e18; // 1e18 precision
        uint256 usdIdr = 16500e18;
        uint256 idrUsd = (1e18 * 1e18) / usdIdr; // Invert

        _setPairRate(fusionXRouterAddr, idrx, usdc, idrUsd);
        _setPairRate(fusionXRouterAddr, usdc, idrx, usdIdr);
        _setPairRate(fusionXRouterAddr, idrx, usdt, idrUsd);
        _setPairRate(fusionXRouterAddr, usdt, idrx, usdIdr);

        _setPairRate(merchantMoeRouterAddr, idrx, usdc, idrUsd);
        _setPairRate(merchantMoeRouterAddr, usdc, idrx, usdIdr);

        _setPairRate(vertexRouterAddr, usdc, usdt, one);
        _setPairRate(vertexRouterAddr, usdt, usdc, one);

        // 3. Deploy Adapters
        address fusionXAdapterAddr = _deployFusionXAdapter(baseSalt, fusionXRouterAddr);
        address merchantMoeAdapterAddr = _deployMerchantMoeAdapter(baseSalt, merchantMoeRouterAddr);
        address vertexAdapterAddr = _deployVertexAdapter(baseSalt, vertexRouterAddr);

        fusionXAdapter = FusionXAdapter(fusionXAdapterAddr);
        merchantMoeAdapter = MerchantMoeAdapter(merchantMoeAdapterAddr);
        vertexAdapter = VertexAdapter(vertexAdapterAddr);

        // 4. Deploy Aggregator & Whitelist Adapters
        address swapAggregatorAddr = _deploySwapAggregator(baseSalt, owner);
        swapAggregator = SwapAggregator(swapAggregatorAddr);
        swapAggregator.addTrustedAdapter(fusionXAdapterAddr);
        swapAggregator.addTrustedAdapter(merchantMoeAdapterAddr);
        swapAggregator.addTrustedAdapter(vertexAdapterAddr);

        vm.stopBroadcast();
    }

    function _deployFusionXRouter(bytes32 baseSalt, address owner) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(FusionXRouter).creationCode, abi.encode(owner)),
            _salt(baseSalt, "FUSIONX_ROUTER"),
            "FusionX router"
        );
    }

    function _deployMerchantMoeRouter(bytes32 baseSalt, address owner) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(MerchantMoeRouter).creationCode, abi.encode(owner)),
            _salt(baseSalt, "MERCHANT_MOE_ROUTER"),
            "MerchantMoe router"
        );
    }

    function _deployVertexRouter(bytes32 baseSalt, address owner) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(VertexRouter).creationCode, abi.encode(owner)),
            _salt(baseSalt, "VERTEX_ROUTER"),
            "Vertex router"
        );
    }

    function _deployFusionXAdapter(bytes32 baseSalt, address router) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(FusionXAdapter).creationCode, abi.encode(router)),
            _salt(baseSalt, "FUSIONX_ADAPTER"),
            "FusionX adapter"
        );
    }

    function _deployMerchantMoeAdapter(bytes32 baseSalt, address router) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(MerchantMoeAdapter).creationCode, abi.encode(router)),
            _salt(baseSalt, "MERCHANT_MOE_ADAPTER"),
            "MerchantMoe adapter"
        );
    }

    function _deployVertexAdapter(bytes32 baseSalt, address router) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(VertexAdapter).creationCode, abi.encode(router)),
            _salt(baseSalt, "VERTEX_ADAPTER"),
            "Vertex adapter"
        );
    }

    function _deploySwapAggregator(bytes32 baseSalt, address owner) internal returns (address) {
        return _deploy(
            abi.encodePacked(type(SwapAggregator).creationCode, abi.encode(owner)),
            _salt(baseSalt, "SWAP_AGGREGATOR"),
            "Swap aggregator"
        );
    }

    function _setPairRate(address router, address tokenIn, address tokenOut, uint256 rate) internal {
        // Use the common interface to set rates
        ISwapRouter(router).setRate(tokenIn, tokenOut, rate);
    }

    function _salt(bytes32 baseSalt, string memory label) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseSalt, label));
    }

    function _predict(bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), EIP2470_FACTORY, salt, initCodeHash)))));
    }

    function _deploy(bytes memory initCode, bytes32 salt, string memory label) internal returns (address deployed) {
        bytes32 initCodeHash = keccak256(initCode);
        address predicted = _predict(salt, initCodeHash);

        console.log(string.concat(label, " predicted:"), predicted);
        deployed = ISingletonFactory(EIP2470_FACTORY).deploy(initCode, salt);
        if (deployed == address(0)) {
            console.log(string.concat(label, " already deployed, using predicted"));
            deployed = predicted;
        } else {
            console.log(string.concat(label, " deployed:"), deployed);
        }
    }
}
