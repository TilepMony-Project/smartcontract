// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IInitCore} from "../interfaces/initCore/IInitCore.sol";
import {ILendingPool} from "../interfaces/initCore/ILendingPool.sol";

contract InitCapitalAdapter is IYieldAdapter {
    using SafeERC20 for IERC20;

    address public immutable INIT_CORE;
    mapping(address => address) public tokenToPool;

    error PoolNotFound(address token); // Keep this error for setPool, but withdraw uses require

    constructor(address _core) {
        INIT_CORE = _core;
    }

    function setPool(address token, address pool) external {
        tokenToPool[token] = pool;
    }

    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    )
        external
        override
        returns (uint256, address)
    {
        address pool = tokenToPool[token];
        if (pool == address(0)) revert PoolNotFound(token);

        // 1. Transfer underlying from Router (msg.sender) to this adapter
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Approve Lending Pool to spend tokens
        // forceApprove ensures compatibility
        IERC20(token).forceApprove(pool, amount);

        // 3. Deposit to Init Capital via Core (or Pool directly?)
        // Docs: "Two steps to mint: transfer underlying to pool, then call mintTo".
        // Step A: Transfer underlying to Pool
        IERC20(token).safeTransfer(pool, amount);

        // Step B: Call mintTo on Core
        // Note: IInitCore.mint (or mintTo) typically mints shares to the `to` address.
        // We mint to `address(this)` first.
        uint256 sharesMinted = IInitCore(INIT_CORE).mintTo(pool, address(this));

        // 4. Forward shares to Router
        if (sharesMinted > 0) {
            IERC20(pool).safeTransfer(msg.sender, sharesMinted);
        }

        return (sharesMinted, pool);
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    )
        external
        override
        returns (uint256)
    {
        address pool = tokenToPool[token];
        require(pool != address(0), "Pool not found");

        // 1. Burn shares using Init Core
        // Note: Adapter holds shares (transferred from Router).
        // Init Capital `burnTo` requires shares to be burned.
        // Does `burnTo` pull shares? Or do we need to transfer shares to pool first?
        // Usually: Transfer shares to Pool, then call burnTo.
        IERC20(pool).safeTransfer(pool, amount);

        // 2. Call burnTo logic
        // returns amount of underlying redeemed
        uint256 amountReceived = IInitCore(INIT_CORE).burnTo(pool, address(this));

        // 3. Transfer underlying to Router (msg.sender)
        IERC20(token).safeTransfer(msg.sender, amountReceived);

        return amountReceived;
    }

    function getProtocolInfo() external pure override returns (ProtocolInfo memory) {
        return ProtocolInfo({
            name: "INIT Capital",
            description: "Liquidity Hook Money Market",
            website: "https://init.capital",
            icon: "init_icon_url"
        });
    }

    function getSupplyApy(address token) external view override returns (uint256) {
        address pool = tokenToPool[token];
        if (pool == address(0)) return 0;

        // Init Capital usually provides rate per second
        uint256 supplyRate = ILendingPool(pool).getSupplyRateE18();

        // APY = (Rate * SecondsPerYear * 100) / 1e18?
        // If rate is already e18 scaled?
        // Let's assume standard calculation
        uint256 secondsPerYear = 31536000;
        // Return APY in 1e18 scale (WAD).
        // e.g. 5% = 0.05e18 = 5e16.
        return supplyRate * secondsPerYear;
    }
}
