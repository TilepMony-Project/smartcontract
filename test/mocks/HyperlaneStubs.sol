// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import {IInterchainGasPaymaster} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainGasPaymaster.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/contracts/interfaces/IInterchainSecurityModule.sol";

contract MockMailbox is IMailbox {
    uint32 public override localDomain;

    constructor(uint32 domain) {
        localDomain = domain;
    }

    function delivered(bytes32) external pure override returns (bool) {
        return false;
    }

    function defaultIsm() external pure override returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    function dispatch(uint32, bytes32, bytes calldata) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function process(bytes calldata, bytes calldata) external pure override {}

    function count() external pure override returns (uint32) {
        return 0;
    }

    function root() external pure override returns (bytes32) {
        return bytes32(0);
    }

    function latestCheckpoint() external pure override returns (bytes32, uint32) {
        return (bytes32(0), 0);
    }

    function recipientIsm(address) external pure override returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
}

    contract MockInterchainGasPaymaster is IInterchainGasPaymaster {
        function payForGas(bytes32, uint32, uint256, address) external payable override {}

        function quoteGasPayment(uint32, uint256) external pure override returns (uint256) {
            return 0;
        }
    }

    contract MockInterchainSecurityModule is IInterchainSecurityModule {
        function moduleType() external pure override returns (uint8) {
            return uint8(Types.NULL);
        }

        function verify(bytes calldata, bytes calldata) external pure override returns (bool) {
            return true;
        }
    }
