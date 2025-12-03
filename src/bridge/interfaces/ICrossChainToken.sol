// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICrossChainToken
 * @notice Minimal interface for the mock cross-chain ERC20 tokens that live under src/token.
 *         The bridge routers rely on the Axelar-style `transferRemote` entrypoint that burns
 *         tokens on the source chain and mints them on the destination chain.
 */
interface ICrossChainToken is IERC20 {
    function transferRemote(string calldata destinationChain, address destinationContract, uint256 amount)
        external
        payable;
}
