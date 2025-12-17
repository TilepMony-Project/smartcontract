// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseBridgeRouter} from "./BaseBridgeRouter.sol";

contract AxelarBridgeRouter is BaseBridgeRouter {
    uint256 private constant BASE_NATIVE_FEE = 0.0005 ether;
    uint256 private constant DATA_BYTE_FEE = 5e11; // 0.0000000005 ether per byte

    constructor(address owner_) BaseBridgeRouter(owner_) {}

    function quoteFee(string calldata destinationChain, uint256 amount, bytes calldata extraData)
        public
        pure
        override
        returns (uint256)
    {
        uint256 metadataCost = extraData.length * DATA_BYTE_FEE;
        uint256 routePremium = bytes(destinationChain).length * 1e12;
        uint256 liquidityFee = (amount * 5) / 10_000; // 0.05%

        return BASE_NATIVE_FEE + metadataCost + routePremium + liquidityFee;
    }

    function _providerId() internal pure override returns (bytes32) {
        return 0x98155e71415442750868f9b9f5f0b5d6255152504620f5c1569426fcd9f58296; // keccak256("AXELAR_ROUTER")
    }
}
