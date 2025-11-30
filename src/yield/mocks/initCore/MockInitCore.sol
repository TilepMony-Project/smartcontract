// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IInitCore} from "../../interfaces/initCore/IInitCore.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockInitCore is IInitCore {
    function mintTo(
        address pool,
        address /* receiver */
    ) external override returns (uint256) {
        // In a real scenario, we would mint shares.
        // For mock, we assume 1:1 ratio and just return the balance of this contract for that pool
        // But wait, the user transferred tokens to the POOL, not here.
        // In this mock, we treat the 'pool' address as the token address for simplicity in the adapter?
        // No, the adapter transfers 'token' to 'pool'.
        // So 'pool' must be a contract that holds tokens.
        // Let's assume 'pool' is the MockLendingPool.

        // For the mock to work simply, we can just return a dummy value or
        // query the pool's balance if we want to be fancy.
        return 100 ether; // Dummy shares
    }

    function burnTo(
        address pool,
        address /* receiver */
    ) external override returns (uint256) {
        return 100 ether; // Dummy amount
    }
}
