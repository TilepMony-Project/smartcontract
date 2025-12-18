// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Common.sol";
import "./TokenProfileScript.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";
import {TokenHypERC20} from "../../src/token/TokenHypERC20.sol";

/// @notice Enroll remote routers for a 2-chain mesh:
/// Base Sepolia <-> Mantle Sepolia (bi-directional).
///
/// Run this script ON EACH CHAIN once.
/// It reads:
///   TOKEN_ADDRESS_* (per chain) or TOKEN_ADDRESS (fallback)
///   *_DOMAIN and ROUTER_* (routers are the token addresses, bytes32-cast)
///
/// Example:
///   MAILBOX=... RPC_URL=... TOKEN_ADDRESS=... forge script ...
contract EnrollRouters is TokenProfileScript {
    using TypeCasts for address;

    function _enroll(TokenHypERC20 token, uint32 domain, address remote) internal {
        token.enrollRemoteRouter(domain, remote.addressToBytes32());
        console2.log("enrolled domain", domain, "->", remote);
    }

    function run() external {
        string memory profile = _activeProfile();
        console2.log("Using token profile:", profile);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        TokenHypERC20 token = TokenHypERC20(_tokenAddressForChain(profile, block.chainid));
        uint32 currentDomain = uint32(block.chainid);

        uint32[] memory domains = new uint32[](2);
        domains[0] = uint32(vm.envUint("BASE_SEPOLIA_DOMAIN"));
        domains[1] = uint32(vm.envUint("MANTLE_SEPOLIA_DOMAIN"));

        address[] memory routers = new address[](2);
        routers[0] = _routerForDomain(profile, domains[0], "ROUTER_BASE_SEPOLIA");
        routers[1] = _routerForDomain(profile, domains[1], "ROUTER_MANTLE_SEPOLIA");

        vm.startBroadcast(pk);

        for (uint256 i = 0; i < domains.length; i++) {
            if (domains[i] == currentDomain) continue;
            _enroll(token, domains[i], routers[i]);
        }

        vm.stopBroadcast();
    }

    function _routerForDomain(string memory profile, uint32 domain, string memory legacyKey)
        internal
        view
        returns (address)
    {
        string memory profileLegacyKey = string.concat(legacyKey, "_", profile);
        address legacyProfile = vm.envOr(profileLegacyKey, address(0));
        if (legacyProfile != address(0)) {
            return legacyProfile;
        }
        address legacy = vm.envOr(legacyKey, address(0));
        if (legacy != address(0)) {
            return legacy;
        }
        return _tokenAddressForChain(profile, domain);
    }
}
