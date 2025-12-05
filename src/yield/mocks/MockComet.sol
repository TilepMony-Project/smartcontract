// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IComet} from "src/yield/interfaces/IComet.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockComet is MockERC20, IComet {
    using SafeERC20 for IERC20;

    address public immutable ASSET;

    // For mocking supply rate
    uint64 public supplyRate = 1e9; // 1e9 per second (mock)
    uint256 public utilization = 50e16; // 50%

    constructor(address _asset) MockERC20("Compound Mock", "cMOCK", 6) {
        ASSET = _asset;
    }

    function baseToken() external view override returns (address) {
        return ASSET;
    }

    function supply(address asset, uint256 amount) external override {
        // Pull assets
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Mint Comet tokens (shares) to user
        // Note: In Compound V3, base token supply logic mints cTokens to user.
        // We inherit MockERC20 so we can mint.
        _mint(msg.sender, amount); // 1:1 for simplicity
    }

    function withdraw(address asset, uint256 amount) external override {
        // Burn Comet tokens from user
        _burn(msg.sender, amount); // 1:1

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
