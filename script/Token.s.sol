// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MockIDRX} from "../src/token/MockIDRX.sol";
import {MockUSDT} from "../src/token/MockUSDT.sol";
import {MockUSDC} from "../src/token/MockUSDC.sol";

contract TokenScript is Script {
    MockIDRX public idrx;
    MockUSDT public usdt;
    MockUSDC public usdc;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        idrx = new MockIDRX();
        console.log("IDRX deployed at:", address(idrx));

        usdt = new MockUSDT();
        console.log("USDT deployed at:", address(usdt));

        usdc = new MockUSDC();
        console.log("USDC deployed at:", address(usdc));

        vm.stopBroadcast();
    }
}
