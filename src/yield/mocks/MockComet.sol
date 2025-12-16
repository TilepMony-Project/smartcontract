// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IComet} from "../interfaces/IComet.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IERC20Metadata
} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockComet is MockERC20, IComet {
    using SafeERC20 for IERC20;

    address public immutable ASSET;

    // For mocking supply rate
    uint64 public supplyRate = 1e9; // 1e9 per second (mock)
    uint256 public utilization = 50e16; // 50%

    // Exchange Rate (1e18 = 1:1)
    uint256 public exchangeRate = 1e18;

    constructor(
        address _asset,
        string memory name,
        string memory symbol
    ) MockERC20(name, symbol, IERC20Metadata(_asset).decimals()) {
        ASSET = _asset;
    }

    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }

    function baseToken() external view override returns (address) {
        return ASSET;
    }

    function supply(address asset, uint256 amount) external override {
        // Pull assets
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate Shares: shares = assets / rate
        uint256 shares = (amount * 1e18) / exchangeRate;

        // Mint Comet tokens (shares) to user
        _mint(msg.sender, shares);
    }

    function withdraw(address asset, uint256 amount) external override {
        // Logic matches Compound V3: 'amount' is Underlying Assets to withdraw

        // Calculate Shares required to burn: shares = (assets * 1e18) / exchangeRate
        // Reversed from supply: shares = (assets * 1e18) / exchangeRate
        uint256 sharesToBurn = (amount * 1e18) / exchangeRate;

        // Burn Comet tokens (shares)
        _burn(msg.sender, sharesToBurn);

        // Transfer assets back to user
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function getSupplyRate(uint256) external view override returns (uint64) {
        return supplyRate;
    }

    function getUtilization() external view override returns (uint256) {
        return utilization;
    }
}
