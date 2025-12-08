// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseBridgeAdapter} from "./BaseBridgeAdapter.sol";

contract AxelarBridgeAdapter is BaseBridgeAdapter {
    constructor(address router_) BaseBridgeAdapter(router_) {}

    function protocol() external pure returns (string memory) {
        return "Axelar";
    }
}
