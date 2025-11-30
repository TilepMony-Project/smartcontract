// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MockToken} from "src/token/MockToken.sol";

/// @notice Script deployment untuk Mock Tokens (mIDRX, mUSDT, mUSDC).
contract DeployMockToken is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerKey);

        console2.log("Deploying Mock Tokens with account:", deployerAddr);

        vm.startBroadcast(deployerKey);

        uint256 initialSupply = 1_000_000_000; // 1 Billion tokens

        // Salt for CREATE2 - ensures same address across chains if deployer is consistent
        bytes32 salt = keccak256(abi.encodePacked("TilepMony_MockTokens_v1"));

        // mIDRX - 18 decimals
        MockToken mIDRX = new MockToken{salt: salt}("Mock IDRX", "mIDRX", 18, initialSupply * 10**18, deployerAddr);
        console2.log("mIDRX deployed at", address(mIDRX));

        // mUSDT - 6 decimals
        MockToken mUSDT = new MockToken{salt: salt}("Mock USDT", "mUSDT", 6, initialSupply * 10**6, deployerAddr);
        console2.log("mUSDT deployed at", address(mUSDT));

        // mUSDC - 6 decimals
        MockToken mUSDC = new MockToken{salt: salt}("Mock USDC", "mUSDC", 6, initialSupply * 10**6, deployerAddr);
        console2.log("mUSDC deployed at", address(mUSDC));

        vm.stopBroadcast();
    }
}
