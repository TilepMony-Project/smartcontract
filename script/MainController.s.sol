// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MainController} from "../src/core/MainController.sol";

contract MainControllerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MainController with deployer as owner
        MainController controller = new MainController(deployer);

        console.log("MainController deployed at:", address(controller));
        console.log("Owner set to:", deployer);

        vm.stopBroadcast();
    }
}
