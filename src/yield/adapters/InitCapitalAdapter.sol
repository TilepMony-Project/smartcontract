// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IInitCore} from "../interfaces/initCore/IInitCore.sol";
import {ILendingPool} from "../interfaces/initCore/ILendingPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InitCapitalAdapter is IYieldAdapter {
    address public immutable initCore;
    mapping(address => address) public underlyingToPool;

    error PoolNotFound(address token);

    constructor(address _initCore) {
        initCore = _initCore;
    }

    function setPool(address token, address pool) external {
        underlyingToPool[token] = pool;
    }

    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256, address) {
        address pool = underlyingToPool[token];
        if (pool == address(0)) revert PoolNotFound(token);

        // 1. Transfer tokens from Router to this adapter
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // 2. Transfer tokens to the Lending Pool
        IERC20(token).transfer(pool, amount);

        // 3. Call mintTo on InitCore
        // Shares are minted to this adapter
        uint256 sharesMinted = IInitCore(initCore).mintTo(pool, address(this));

        // 4. Forward shares to Router
        IERC20(pool).transfer(msg.sender, sharesMinted);

        return (sharesMinted, pool);
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        address pool = underlyingToPool[token];
        if (pool == address(0)) revert PoolNotFound(token);

        // 1. Transfer shares (pool token) to the Lending Pool
        // Note: 'amount' here is treated as shares amount for simplicity,
        // or we need a way to convert. The interface says 'amount' of tokens to withdraw?
        // Usually withdraw takes share amount or asset amount.
        // InitCore burnTo takes 'pool' and 'receiver'. It likely burns ALL shares sent to the pool?
        // Or it burns what was transferred.
        // Let's assume we transfer 'amount' of shares.
        IERC20(pool).transfer(pool, amount);

        // 2. Call burnTo on InitCore
        uint256 amountReceived = IInitCore(initCore).burnTo(
            pool,
            address(this)
        );

        // 3. Transfer underlying tokens to Router (msg.sender)
        IERC20(token).transfer(msg.sender, amountReceived);

        return amountReceived;
    }

    function getProtocolInfo()
        external
        pure
        override
        returns (ProtocolInfo memory)
    {
        return
            ProtocolInfo({
                name: "INIT Capital",
                description: "Liquidity Hook Money Market",
                website: "https://init.capital",
                icon: "init_icon_url"
            });
    }

    function getSupplyAPY(address token) external view returns (uint256) {
        address pool = underlyingToPool[token];
        if (pool == address(0)) return 0;

        uint256 rate = ILendingPool(pool).getSupplyRate_e18();
        // Rate is per second scaled by 1e18
        return (rate * 365 days * 100) / 1e18;
    }
}
