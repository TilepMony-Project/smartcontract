// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {AxelarBridgeRouter} from "../src/bridge/routers/AxelarBridgeRouter.sol";
import {AxelarBridgeAdapter} from "../src/bridge/adapters/AxelarBridgeAdapter.sol";

contract BridgeScript is Script {
    using stdJson for string;

    bytes32 internal constant ROUTER_SALT = keccak256("AxelarBridgeRouter_V1");
    bytes32 internal constant ADAPTER_SALT = keccak256("AxelarBridgeAdapter_V1");
    address internal constant CREATE2_FACTORY_ADDR = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

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
        address owner = deployer;

        vm.startBroadcast(deployerPrivateKey);

        AxelarBridgeRouter router = _deployRouter(owner);
        AxelarBridgeAdapter adapter = _deployAdapter(address(router));

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

    function _deployRouter(address owner) internal returns (AxelarBridgeRouter router) {
        bytes memory bytecode = abi.encodePacked(type(AxelarBridgeRouter).creationCode, abi.encode(owner));
        bytes32 initCodeHash = keccak256(bytecode);
        address predicted = vm.computeCreate2Address(ROUTER_SALT, initCodeHash, CREATE2_FACTORY_ADDR);

        if (predicted.code.length == 0) {
            router = new AxelarBridgeRouter{salt: ROUTER_SALT}(owner);
            require(address(router) == predicted, "Router address mismatch");
            console.log("AxelarBridgeRouter deployed at:", address(router));
            console.log("Router owner:", owner);
        } else {
            router = AxelarBridgeRouter(predicted);
            console.log("AxelarBridgeRouter already deployed at:", predicted);
        }
    }

    function _deployAdapter(address routerAddr) internal returns (AxelarBridgeAdapter adapter) {
        bytes memory bytecode = abi.encodePacked(type(AxelarBridgeAdapter).creationCode, abi.encode(routerAddr));
        bytes32 initCodeHash = keccak256(bytecode);
        address predicted = vm.computeCreate2Address(ADAPTER_SALT, initCodeHash, CREATE2_FACTORY_ADDR);

        if (predicted.code.length == 0) {
            adapter = new AxelarBridgeAdapter{salt: ADAPTER_SALT}(routerAddr);
            require(address(adapter) == predicted, "Adapter address mismatch");
            console.log("AxelarBridgeAdapter deployed at:", address(adapter));
        } else {
            adapter = AxelarBridgeAdapter(predicted);
            console.log("AxelarBridgeAdapter already deployed at:", predicted);
        }
    }
}
