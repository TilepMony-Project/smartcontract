// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Minimal interface for the EIP-2470 Singleton Factory.
interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
}

library Env {
    Vm private constant CHEATS = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function str(string memory key) internal view returns (string memory) {
        return CHEATS.envString(key);
    }

    function addr(string memory key) internal view returns (address) {
        return CHEATS.envAddress(key);
    }

    function u(string memory key) internal view returns (uint256) {
        return CHEATS.envUint(key);
    }

    function u8(string memory key) internal view returns (uint8) {
        return uint8(CHEATS.envUint(key));
    }

    function b32FromSaltString(string memory key) internal view returns (bytes32) {
        // Take a human string and hash it into bytes32.
        // This gives you a stable bytes32 even if you store a plain string in .env
        return keccak256(bytes(CHEATS.envString(key)));
    }
}
