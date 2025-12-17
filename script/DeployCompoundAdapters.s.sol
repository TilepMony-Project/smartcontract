// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CompoundAdapter} from "../src/yield/adapters/CompoundAdapter.sol";

interface IYieldRouter {
    function setAdapterWhitelist(address adapter, bool status) external;
}

contract DeployCompoundAdapters is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        address yieldRouter = 0xFD5d839EF67bb50a3395f2974419274B47D7cb90;

        // Comets
        address idrxComet = 0xAaeBE3d3A7DFcC4c2C334E007dc4339d7669a411;
        address usdcComet = 0x375b705311059aadaC34fe4BEa3C569adc4dcA8D;
        address usdtComet = 0xC88C22A769FB69fD6Ed690E927f3F1CCCaDF9180;

        // Deploy New Adapters
        CompoundAdapter adapterIDRX = new CompoundAdapter(idrxComet);
        console.log("New CompoundAdapter IDRX:", address(adapterIDRX));

        CompoundAdapter adapterUSDC = new CompoundAdapter(usdcComet);
        console.log("New CompoundAdapter USDC:", address(adapterUSDC));

        CompoundAdapter adapterUSDT = new CompoundAdapter(usdtComet);
        console.log("New CompoundAdapter USDT:", address(adapterUSDT));

        // Whitelist New Adapters
        IYieldRouter(yieldRouter).setAdapterWhitelist(address(adapterIDRX), true);
        IYieldRouter(yieldRouter).setAdapterWhitelist(address(adapterUSDC), true);
        IYieldRouter(yieldRouter).setAdapterWhitelist(address(adapterUSDT), true);

        // Optional: Blacklist Old Adapters?
        // Old addresses:
        // IDRX: 0x3beb89f49f2d3f35a4f5e3374edc73fa9b03ad57
        // USDC: 0x69cb5590ac1c3a717afbeb0228bfc905333243a7
        // USDT: 0xd7cee5fada0baca0c5945acb19963028b08062c2
        IYieldRouter(yieldRouter).setAdapterWhitelist(0x3bEb89F49F2D3f35A4F5E3374EdC73FA9b03AD57, false);
        IYieldRouter(yieldRouter).setAdapterWhitelist(0x69CB5590Ac1C3A717aFbEB0228bfC905333243a7, false);
        IYieldRouter(yieldRouter).setAdapterWhitelist(0xd7cEE5faDa0BaCa0c5945acB19963028b08062c2, false);

        vm.stopBroadcast();
    }
}
