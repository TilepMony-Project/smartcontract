// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MockIDRX} from "../src/token/MockIDRX.sol";
import {MockUSDT} from "../src/token/MockUSDT.sol";

contract TokenScript is Script {
    MockIDRX public idrx;
    MockUSDT public usdt;

    function run() public returns (address idrxAddress, address usdtAddress) {
      vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

      idrx = new MockIDRX();
      idrxAddress = address(idrx);

      console.log("IDRX deployed at:", address(idrx));

      usdt = new MockUSDT();
      usdtAddress = address(usdt);

      console.log("USDT deployed at:", address(usdt));

      vm.stopBroadcast();
    }
}
