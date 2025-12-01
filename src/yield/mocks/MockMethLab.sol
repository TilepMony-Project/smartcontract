// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IMethLab} from "../interfaces/IMethLab.sol";

contract MockMethLab is IMethLab, ERC20 {
    IERC20 public immutable asset;
    uint256 public exchangeRate = 1e18; // 1 share = 1 asset initially
    uint256 public currentAPY = 5e16; // Default 5% APY
    uint256 public lockUntil;

    error FundsLocked(uint256 unlockTime);

    constructor(address _asset) ERC20("MethLab Mock", "mMOCK") {
        asset = IERC20(_asset);
    }

    function deposit(
        uint256 amount,
        address receiver
    ) external override returns (uint256 shares) {
        shares = (amount * 1e18) / exchangeRate;
        asset.transferFrom(msg.sender, address(this), amount);
        _mint(receiver, shares);
    }

    function withdraw(
        uint256 shares,
        address receiver
    ) external override returns (uint256 assets) {
        if (block.timestamp < lockUntil) revert FundsLocked(lockUntil);

        assets = (shares * exchangeRate) / 1e18;
        _burn(msg.sender, shares);
        asset.transfer(receiver, assets);
    }

    function convertToAssets(
        uint256 shares
    ) external view override returns (uint256) {
        return (shares * exchangeRate) / 1e18;
    }

    function convertToShares(
        uint256 assets
    ) external view override returns (uint256) {
        return (assets * 1e18) / exchangeRate;
    }

    // Helper to simulate yield
    function setExchangeRate(uint256 newRate) external {
        exchangeRate = newRate;
    }

    // Helper to set APY (Testnet feature)
    function setAPY(uint256 _apy) external {
        currentAPY = _apy;
    }

    // Helper to set Lock (Testnet feature)
    function setLock(uint256 _timestamp) external {
        lockUntil = _timestamp;
    }

    function getAPY() external view override returns (uint256) {
        return currentAPY;
    }
}
