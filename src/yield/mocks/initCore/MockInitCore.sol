// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IInitCore} from "../../interfaces/initCore/IInitCore.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ILendingPool} from "../../interfaces/initCore/ILendingPool.sol";
import {MockLendingPool} from "./MockLendingPool.sol";

import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MockInitCore is IInitCore {
    function mintTo(address pool, address receiver) external override returns (uint256) {
        // Mint 100 ether shares (assuming shares are always 18 decimals)
        uint256 amount = 100 ether;
        MockLendingPool(pool).mint(receiver, amount);
        return amount;
    }

    function burnTo(address pool, address receiver) external override returns (uint256) {
        address underlying = ILendingPool(pool).underlyingToken();
        uint8 decimals = IERC20Metadata(underlying).decimals();

        uint256 amount = 100 * (10 ** decimals);

        IERC20(underlying).transferFrom(pool, receiver, amount);
        return amount;
    }
}
