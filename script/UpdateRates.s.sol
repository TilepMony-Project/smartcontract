// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ISwapRouter} from "../src/swap/interfaces/ISwapRouter.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UpdateRates is Script {
    struct TokenDecimals {
        uint8 idrx;
        uint8 usdc;
        uint8 usdt;
    }

    function _envAddress(string memory key) internal view returns (address) {
        return vm.envAddress(key);
    }

    function _envString(string memory key, string memory defaultValue) internal view returns (string memory) {
        return vm.envOr(key, defaultValue);
    }

    function _getTokenDecimals(address idrx, address usdc, address usdt) internal view returns (TokenDecimals memory) {
        return TokenDecimals({
            idrx: IERC20Metadata(idrx).decimals(),
            usdc: IERC20Metadata(usdc).decimals(),
            usdt: IERC20Metadata(usdt).decimals()
        });
    }

    /// @dev Returns a rate scaled to 1e18 that accounts for differing token decimals.
    function _scaledRate(uint256 priceNumerator, uint256 priceDenominator, uint8 decimalsOut, uint8 decimalsIn)
        internal
        pure
        returns (uint256)
    {
        // rate = (priceNumerator / priceDenominator) * 10^(decimalsOut - decimalsIn) * 1e18
        return priceNumerator * (10 ** decimalsOut) * 1e18 / (priceDenominator * (10 ** decimalsIn));
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

        TokenDecimals memory decs = _getTokenDecimals(idrx, usdc, usdt);

        console.log("Updating Rates for mTokens...");
        console.log("Chain profile:", chainProfile);
        console.log("FusionX router:", fusionXRouter);
        console.log("MerchantMoe router:", merchantMoeRouter);
        console.log("Vertex router:", vertexRouter);
        console.log("IDRX:", idrx);
        console.log("USDC:", usdc);
        console.log("USDT:", usdt);
        console.log("Decimals (IDRX, USDC, USDT):", decs.idrx, decs.usdc, decs.usdt);

        // 1. FusionX
        ISwapRouter(fusionXRouter).setRate(idrx, usdc, _scaledRate(1, 16_500, decs.usdc, decs.idrx));
        ISwapRouter(fusionXRouter).setRate(usdc, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdc));
        ISwapRouter(fusionXRouter).setRate(idrx, usdt, _scaledRate(1, 16_500, decs.usdt, decs.idrx));
        ISwapRouter(fusionXRouter).setRate(usdt, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdt));
        ISwapRouter(fusionXRouter).setRate(usdc, usdt, _scaledRate(1, 1, decs.usdt, decs.usdc));
        ISwapRouter(fusionXRouter).setRate(usdt, usdc, _scaledRate(1, 1, decs.usdc, decs.usdt));
        console.log("FusionX Rates Updated");

        // 2. MerchantMoe
        ISwapRouter(merchantMoeRouter).setRate(idrx, usdc, _scaledRate(1, 16_500, decs.usdc, decs.idrx));
        ISwapRouter(merchantMoeRouter).setRate(usdc, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdc));
        ISwapRouter(merchantMoeRouter).setRate(idrx, usdt, _scaledRate(1, 16_500, decs.usdt, decs.idrx));
        ISwapRouter(merchantMoeRouter).setRate(usdt, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdt));
        ISwapRouter(merchantMoeRouter).setRate(usdc, usdt, _scaledRate(1, 1, decs.usdt, decs.usdc));
        ISwapRouter(merchantMoeRouter).setRate(usdt, usdc, _scaledRate(1, 1, decs.usdc, decs.usdt));
        console.log("MerchantMoe Rates Updated");

        // 3. Vertex (Stable-Stable)
        ISwapRouter(vertexRouter).setRate(usdc, usdt, _scaledRate(1, 1, decs.usdt, decs.usdc));
        ISwapRouter(vertexRouter).setRate(usdt, usdc, _scaledRate(1, 1, decs.usdc, decs.usdt));
        ISwapRouter(vertexRouter).setRate(idrx, usdc, _scaledRate(1, 16_500, decs.usdc, decs.idrx));
        ISwapRouter(vertexRouter).setRate(usdc, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdc));
        ISwapRouter(vertexRouter).setRate(idrx, usdt, _scaledRate(1, 16_500, decs.usdt, decs.idrx));
        ISwapRouter(vertexRouter).setRate(usdt, idrx, _scaledRate(16_500, 1, decs.idrx, decs.usdt));
        console.log("Vertex Rates Updated");

        vm.stopBroadcast();
    }
}
