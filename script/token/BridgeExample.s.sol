// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Common.sol";
import "./TokenProfileScript.sol";
import {TokenHypERC20} from "../../src/token/TokenHypERC20.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

/// @notice Example: bridge tokens using transferRemote.
/// This is a convenience script for quick manual testing.
contract BridgeExample is TokenProfileScript {
    using TypeCasts for address;

    function run() external payable {
        string memory profile = _activeProfile();
        console2.log("Using token profile:", profile);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = _tokenAddressForChain(profile, block.chainid);
        TokenHypERC20 token = TokenHypERC20(tokenAddr);

        uint32 destination = uint32(vm.envUint("DEST_DOMAIN"));
        address recipient = vm.envAddress("RECIPIENT");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 gasPayment = vm.envUint("GAS_PAYMENT");
        bytes memory additionalData = vm.envOr("ADDITIONAL_DATA", bytes(""));

        vm.startBroadcast(pk);
        bytes32 msgId;
        if (additionalData.length > 0) {
            msgId = token.transferRemoteWithPayload{value: gasPayment}(
                destination, recipient.addressToBytes32(), amount, additionalData
            );
        } else {
            // Uses token's configured hook (can be zero => mailbox default hook).
            msgId = token.transferRemote{value: gasPayment}(destination, recipient.addressToBytes32(), amount);
        }
        vm.stopBroadcast();

        console2.logBytes32(msgId);
    }
}
