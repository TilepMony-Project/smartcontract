// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/// @notice Shared helper for scripts that need to work with multiple token profiles.
abstract contract TokenProfileScript is Script {
    string internal constant DEFAULT_PROFILE = "MIDRX";

    function _activeProfile() internal view returns (string memory) {
        return vm.envOr("TOKEN_PROFILE", DEFAULT_PROFILE);
    }

    function _profileKey(string memory profile, string memory suffix) internal pure returns (string memory) {
        return string.concat("TOKEN_", profile, "_", suffix);
    }

    function _profileString(
        string memory profile,
        string memory suffix,
        string memory globalKey,
        string memory defaultValue
    ) internal view returns (string memory) {
        string memory globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileUint(string memory profile, string memory suffix, string memory globalKey, uint256 defaultValue)
        internal
        view
        returns (uint256)
    {
        uint256 globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileAddress(string memory profile, string memory suffix, string memory globalKey, address defaultValue)
        internal
        view
        returns (address)
    {
        address globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileAddressOrZero(string memory profile, string memory suffix) internal view returns (address) {
        string memory key = _profileKey(profile, suffix);
        return vm.envOr(key, address(0));
    }

    function _profileChainAddress(string memory profile, string memory chainSuffix, string memory fallbackKey)
        internal
        view
        returns (address)
    {
        string memory profileChainKey = string.concat("TOKEN_ADDRESS_", chainSuffix, "_", profile);
        address fallbackValue = vm.envOr(fallbackKey, address(0));
        address profileValue = vm.envOr(profileChainKey, fallbackValue);
        if (profileValue != address(0)) {
            return profileValue;
        }
        string memory generalProfileKey = string.concat("TOKEN_ADDRESS_", profile);
        address generalProfileValue = vm.envOr(generalProfileKey, address(0));
        if (generalProfileValue != address(0)) {
            return generalProfileValue;
        }
        address globalAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        require(globalAddress != address(0), "TOKEN_ADDRESS missing for fallback");
        return globalAddress;
    }

    function _tokenAddressForChain(string memory profile, uint256 chainId) internal view returns (address) {
        if (chainId == vm.envUint("BASE_SEPOLIA_DOMAIN")) {
            return _profileChainAddress(profile, "BASE", "TOKEN_ADDRESS_BASE");
        }
        if (chainId == vm.envUint("MANTLE_SEPOLIA_DOMAIN")) {
            return _profileChainAddress(profile, "MANTLE", "TOKEN_ADDRESS_MANTLE");
        }
        string memory generalProfileKey = string.concat("TOKEN_ADDRESS_", profile);
        address profileGeneral = vm.envOr(generalProfileKey, address(0));
        if (profileGeneral != address(0)) {
            return profileGeneral;
        }
        address globalAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        require(globalAddress != address(0), "TOKEN_ADDRESS missing for fallback");
        return globalAddress;
    }
}
