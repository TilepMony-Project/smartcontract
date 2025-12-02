// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MockIDRXCrossChain} from "../src/token/MockIDRXCrossChain.sol";
import {MockUSDCCrossChain} from "../src/token/MockUSDCCrossChain.sol";
import {MockUSDTCrossChain} from "../src/token/MockUSDTCrossChain.sol";

interface ICrossChainToken {
    function initAxelar(address gateway_, address gasReceiver_) external;
}

contract TokenCrossChain is Script {
    using stdJson for string;

    bytes32 private constant IDRX_TOKEN = keccak256("IDRX");
    bytes32 private constant USDC_TOKEN = keccak256("USDC");
    bytes32 private constant USDT_TOKEN = keccak256("USDT");

    function run() external {
        uint256 chainId = block.chainid;
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/chains.json");
        string memory json = vm.readFile(path);
        string memory chainIdStr = vm.toString(chainId);
        
        // Read the prefix from chains.json based on chainId
        // Note: stdJson requires the key to start with "."
        string memory chainPrefix = json.readString(string.concat(".", chainIdStr));

        console.log("Detected Chain ID:", chainId);
        console.log("Using Env Prefix:", chainPrefix);

        // Construct env vars based on prefix
        string memory gatewayKey = string.concat(chainPrefix, "_AXELAR_GATEWAY");
        string memory gasServiceKey = string.concat(chainPrefix, "_AXELAR_GAS_SERVICE");
        
        // Read from env
        address gateway = vm.envAddress(gatewayKey);
        address gasService = vm.envAddress(gasServiceKey);
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        _deployAndInit("IDRX", gateway, gasService);
        _deployAndInit("USDC", gateway, gasService);
        _deployAndInit("USDT", gateway, gasService);

        vm.stopBroadcast();
    }

    function _deployAndInit(
        string memory tokenVariant,
        address gateway,
        address gasService
    ) internal {
        console.log(string.concat("Deploying token variant: ", tokenVariant));

        bytes32 salt = keccak256(bytes(string.concat("CrossChainToken_V1", tokenVariant)));

        address deployedToken = _deployToken(tokenVariant, salt);

        console.log("Deployed cross-chain token at:", deployedToken);

        _initAxelar(deployedToken, gateway, gasService);
        console.log("Initialized Axelar config");
    }

    function _deployToken(string memory tokenVariant, bytes32 salt) internal returns (address) {
        bytes32 variantHash = keccak256(bytes(tokenVariant));

        if (variantHash == IDRX_TOKEN) {
            MockIDRXCrossChain token = new MockIDRXCrossChain{salt: salt}();
            return address(token);
        } else if (variantHash == USDC_TOKEN) {
            MockUSDCCrossChain token = new MockUSDCCrossChain{salt: salt}();
            return address(token);
        } else if (variantHash == USDT_TOKEN) {
            MockUSDTCrossChain token = new MockUSDTCrossChain{salt: salt}();
            return address(token);
        }

        revert("Unsupported token variant");
    }

    function _initAxelar(address token, address gateway, address gasService) internal {
        ICrossChainToken(token).initAxelar(gateway, gasService);
    }
}
