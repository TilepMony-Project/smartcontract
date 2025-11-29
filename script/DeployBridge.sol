// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {BridgeLayer} from "src/bridge/BridgeLayer.sol";
import {AxelarBridgeAdapter} from "src/bridge/adapters/AxelarBridgeAdapter.sol";

/// @notice Foundry deployment script untuk BridgeLayer + AxelarBridgeAdapter.
///         Membaca konfigurasi dari file `.env` (lihat `.env.example`).
contract DeployBridge is Script {
    struct DeployedContracts {
        address bridgeLayer;
        address axelarAdapter;
    }

    error DestinationConfigMismatch(uint256 ids, uint256 names, uint256 receivers);

    function run() external returns (DeployedContracts memory deployed) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address expectedOwner = vm.envAddress("OWNER");
        address deployerAddr = vm.addr(deployerKey);

        require(deployerAddr == expectedOwner, "Deploy: OWNER env must match PRIVATE_KEY address");

        address gateway = vm.envAddress("AXELAR_GATEWAY");
        address gasService = vm.envAddress("AXELAR_GAS_SERVICE");

        vm.startBroadcast(deployerKey);

        AxelarBridgeAdapter adapter = new AxelarBridgeAdapter(gateway, gasService);
        BridgeLayer bridgeLayer = new BridgeLayer();

        bridgeLayer.setAxelarAdapter(address(adapter));
        _configureDestinations(adapter);

        vm.stopBroadcast();

        deployed = DeployedContracts({bridgeLayer: address(bridgeLayer), axelarAdapter: address(adapter)});

        console2.log("AxelarBridgeAdapter deployed at", deployed.axelarAdapter);
        console2.log("BridgeLayer deployed at", deployed.bridgeLayer);
    }

    /// @dev Set konfigurasi destinasi jika tersedia pada env.
    function _configureDestinations(AxelarBridgeAdapter adapter) internal {
        if (!vm.envExists("DST_CHAIN_IDS")) {
            console2.log("DST_CHAIN_IDS not set, skipping destination config");
            return;
        }

        uint256[] memory chainIds = vm.envUint("DST_CHAIN_IDS", ",");
        if (chainIds.length == 0) {
            console2.log("DST_CHAIN_IDS empty, skipping destination config");
            return;
        }

        if (!vm.envExists("AXELAR_CHAIN_NAMES") || !vm.envExists("AXELAR_DEST_RECEIVERS")) {
            revert DestinationConfigMismatch(chainIds.length, 0, 0);
        }

        string[] memory axelarNames = vm.envString("AXELAR_CHAIN_NAMES", ",");
        string[] memory receivers = vm.envString("AXELAR_DEST_RECEIVERS", ",");

        if (chainIds.length != axelarNames.length || chainIds.length != receivers.length) {
            revert DestinationConfigMismatch(chainIds.length, axelarNames.length, receivers.length);
        }

        for (uint256 i = 0; i < chainIds.length; i++) {
            adapter.setDestination(chainIds[i], axelarNames[i], receivers[i]);
            console2.log("Configured dstChainId", chainIds[i]);
            console2.log("    Axelar chain", axelarNames[i]);
            console2.log("    Receiver", receivers[i]);
        }
    }
}
