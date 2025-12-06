// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {AxelarBridgeRouter} from "../src/bridge/routers/AxelarBridgeRouter.sol";
import {AxelarBridgeAdapter} from "../src/bridge/adapters/AxelarBridgeAdapter.sol";

contract BridgeScript is Script {
    using stdJson for string;

    struct TokenHint {
        string label;
        string envSuffix;
    }

    TokenHint[] internal supportedTokens;

    constructor() {
        supportedTokens.push(TokenHint({label: "mIDRX", envSuffix: "MIDRX_TOKEN"}));
        supportedTokens.push(TokenHint({label: "mUSDC", envSuffix: "MUSDC_TOKEN"}));
        supportedTokens.push(TokenHint({label: "mUSDT", envSuffix: "MUSDT_TOKEN"}));
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        (string memory prefix,) = _readChainPrefix();

        address owner = _readAddressOr(string.concat(prefix, "_BRIDGE_OWNER"), deployer);

        vm.startBroadcast(deployerPrivateKey);

        AxelarBridgeRouter router = new AxelarBridgeRouter(owner);
        console.log("AxelarBridgeRouter deployed at:", address(router));
        console.log("Router owner:", owner);

        AxelarBridgeAdapter adapter = new AxelarBridgeAdapter(address(router));
        console.log("AxelarBridgeAdapter deployed at:", address(adapter));

        _configureSupportedTokens(router, prefix);

        vm.stopBroadcast();
    }

    function _configureSupportedTokens(AxelarBridgeRouter router, string memory prefix) internal {
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            string memory envKey = string.concat(prefix, "_", supportedTokens[i].envSuffix);
            (address tokenAddr, bool exists) = _readAddressOptional(envKey);
            if (!exists || tokenAddr == address(0)) {
                console.log(string.concat("Skipping token (missing env): ", supportedTokens[i].label));
                continue;
            }

            router.setSupportedToken(tokenAddr, true);
            console.log(string.concat("Enabled token ", supportedTokens[i].label, " at address:"), tokenAddr);
        }
    }

    function _readChainPrefix() internal view returns (string memory prefix, string memory chainIdStr) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/chains.json");
        string memory json = vm.readFile(path);
        chainIdStr = vm.toString(block.chainid);
        prefix = json.readString(string.concat(".", chainIdStr));
    }

    function _readAddressOptional(string memory key) internal returns (address value, bool exists) {
        try vm.envAddress(key) returns (address addr) {
            value = addr;
            exists = true;
        } catch {
            value = address(0);
            exists = false;
        }
    }

    function _readAddressOr(string memory key, address defaultValue) internal returns (address) {
        (address value, bool exists) = _readAddressOptional(key);
        return exists ? value : defaultValue;
    }
}
