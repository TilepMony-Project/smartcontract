// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockComet} from "../src/yield/mocks/MockComet.sol";
import {CompoundAdapter} from "../src/yield/adapters/CompoundAdapter.sol";
import {YieldRouter} from "../src/yield/YieldRouter.sol";

contract DeployCometsAndAdapters is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Tokens
        address idrx = 0xc39DfE81DcAd49F1Da4Ff8d41f723922Febb75dc;
        address usdc = 0x681db03Ef13e37151e9fd68920d2c34273194379;
        address usdt = 0x9a82fC0c460A499b6ce3d6d8A29835a438B5Ec28;

        YieldRouter router = YieldRouter(0xFD5d839EF67bb50a3395f2974419274B47D7cb90);

        // 1. Deploy New Mock Comets (Fixed Logic)
        MockComet cometIdrx = new MockComet(idrx, "Compound IDRX", "cIDRXv3");
        MockComet cometUsdc = new MockComet(usdc, "Compound USDC", "cUSDCv3");
        MockComet cometUsdt = new MockComet(usdt, "Compound USDT", "cUSDTv3");

        // Set Exchange Rates (1.1)
        cometIdrx.setExchangeRate(1.1e18);
        cometUsdc.setExchangeRate(1.1e18);
        cometUsdt.setExchangeRate(1.1e18);

        // 2. Deploy New Adapters (Pointing to New Comets)
        CompoundAdapter adapterIdrx = new CompoundAdapter(address(cometIdrx));
        CompoundAdapter adapterUsdc = new CompoundAdapter(address(cometUsdc));
        CompoundAdapter adapterUsdt = new CompoundAdapter(address(cometUsdt));

        // 3. Whitelist New Adapters
        // 3. Whitelist New Adapters
        router.setAdapterWhitelist(address(adapterIdrx), true);
        router.setAdapterWhitelist(address(adapterUsdc), true);
        router.setAdapterWhitelist(address(adapterUsdt), true);

        // 4. Blacklist Old Adapters (Optional, but good practice)
        // Hardcoded old addresses from config
        router.setAdapterWhitelist(0x23BBF514815ac25d4FECC075C9a7E3fC18Dd1207, false); // Old IDRX
        router.setAdapterWhitelist(0x53A4AEf6dAE3695271BC697eB042e9C0D31F9D87, false); // Old USDC
        router.setAdapterWhitelist(0x8E50D79967c3932B8f4F6EA014A407AB925F3284, false); // Old USDT

        vm.stopBroadcast();
    }
}
