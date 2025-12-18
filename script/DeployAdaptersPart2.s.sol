// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockComet} from "../src/yield/mocks/MockComet.sol";
import {CompoundAdapter} from "../src/yield/adapters/CompoundAdapter.sol";
import {YieldRouter} from "../src/yield/YieldRouter.sol";

contract DeployAdaptersPart2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        YieldRouter router = YieldRouter(0xFD5d839EF67bb50a3395f2974419274B47D7cb90);

        // Already Deployed Comets
        MockComet cometIdrx = MockComet(0xADC863d35179FB78D05Cd7bC270117D47cB7c366);
        MockComet cometUsdc = MockComet(0x36EcF1A5e8FB62Ab7289B8EAeb1083F1211679FD);
        MockComet cometUsdt = MockComet(0xb01a0Dbb3334da1087f87e70FB5149dA1093E6a2);

        // Set Exchange Rates (1.1)
        // Try/Catch just in case validation or something fails, though unlikely for Mock
        cometIdrx.setExchangeRate(1.1e18);
        cometUsdc.setExchangeRate(1.1e18);
        cometUsdt.setExchangeRate(1.1e18);

        // 2. Deploy New Adapters (Pointing to These Comets)
        CompoundAdapter adapterIdrx = new CompoundAdapter(address(cometIdrx));
        CompoundAdapter adapterUsdc = new CompoundAdapter(address(cometUsdc));
        CompoundAdapter adapterUsdt = new CompoundAdapter(address(cometUsdt));

        // 3. Whitelist New Adapters
        router.setAdapterWhitelist(address(adapterIdrx), true);
        router.setAdapterWhitelist(address(adapterUsdc), true);
        router.setAdapterWhitelist(address(adapterUsdt), true);

        // 4. Blacklist Old Adapters
        router.setAdapterWhitelist(0x23BBF514815ac25d4FECC075C9a7E3fC18Dd1207, false); // Old IDRX
        router.setAdapterWhitelist(0x53A4AEf6dAE3695271BC697eB042e9C0D31F9D87, false); // Old USDC
        router.setAdapterWhitelist(0x8E50D79967c3932B8f4F6EA014A407AB925F3284, false); // Old USDT

        vm.stopBroadcast();
    }
}
