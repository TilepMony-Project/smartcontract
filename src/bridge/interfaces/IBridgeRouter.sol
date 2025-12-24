// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBridgeRouter {
    function bridge(
        address _tokenAddress,
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _additionalData
    ) external payable;
}
