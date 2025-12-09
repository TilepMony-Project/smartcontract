// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IInitCore} from "../../interfaces/initCore/IInitCore.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILendingPool} from "../../interfaces/initCore/ILendingPool.sol";
import {MockLendingPool} from "./MockLendingPool.sol";

import {
    IERC20Metadata
} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MockInitCore is IInitCore {
    using SafeERC20 for IERC20;

    function mintTo(
        address pool,
        address receiver
    ) external override returns (uint256) {
        // Dynamic Logic with Exchange Rate
        // 1. Get total underlying assets in pool
        address underlying = ILendingPool(pool).underlyingToken();
        uint256 totalAssets = IERC20(underlying).balanceOf(pool);

        // 2. Get total shares minted
        uint256 totalShares = MockLendingPool(pool).totalSupply();
        uint256 exchangeRate = MockLendingPool(pool).exchangeRate();

        // 3. Calculate expected shares based on total assets and rate
        // shares = totalAssets * 1e18 / rate
        uint256 requiredShares = (totalAssets * 1e18) / exchangeRate;

        if (requiredShares <= totalShares) return 0; // No new deposit

        uint256 amountToMint = requiredShares - totalShares;

        // 4. Mint shares to receiver
        MockLendingPool(pool).mint(receiver, amountToMint);
        return amountToMint;
    }

    function burnTo(
        address pool,
        address receiver
    ) external override returns (uint256) {
        address underlying = ILendingPool(pool).underlyingToken();

        // 1. Get shares held by the Pool (User/Router transfers shares to Pool before burning)
        uint256 sharesToBurn = MockLendingPool(pool).balanceOf(pool);
        uint256 exchangeRate = MockLendingPool(pool).exchangeRate();

        // 2. Burn shares
        MockLendingPool(pool).burn(pool, sharesToBurn);

        // 3. Return underlying assets
        // assets = shares * rate / 1e18
        uint256 amountToReturn = (sharesToBurn * exchangeRate) / 1e18;

        IERC20(underlying).safeTransferFrom(pool, receiver, amountToReturn);

        return amountToReturn;
    }
}
