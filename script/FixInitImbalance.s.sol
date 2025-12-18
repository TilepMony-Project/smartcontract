// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IInitCore {
    function mintTo(address pool, address receiver) external returns (uint256);
}

interface IInitAdapter {
    function INIT_CORE() external view returns (address);
}

contract FixInitImbalance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Init Capital Adapter
        address adapter = 0x9738885A3946456F471c17F43dd421eBe7ceB0ef;
        address core = IInitAdapter(adapter).INIT_CORE();
        console.log("Init Core:", core);

        address[] memory pools = new address[](3);
        pools[0] = 0x6Adaa6312b785fcbf4904BA505Ecff4f3fe2b4e2; // IDRX
        pools[1] = 0x2e01d3672be5978a0CcEada25097325f255F76e8; // USDC
        pools[2] = 0x99a13d0D22025EbeE7958BE133022Aa17E63a821; // USDT

        string[] memory symbols = new string[](3);
        symbols[0] = "IDRX";
        symbols[1] = "USDC";
        symbols[2] = "USDT";

        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            console.log("Fixing pool:", symbols[i], pool);
            try IInitCore(core).mintTo(pools[i], deployer) returns (uint256 minted) {
                console.log("Minted correction shares:", minted);
            } catch {
                console.log("Failed to mint or no correction needed.");
            }
        }

        vm.stopBroadcast();
    }
}
