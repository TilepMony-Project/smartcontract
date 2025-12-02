// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IComet} from "../interfaces/IComet.sol";

contract CompoundAdapter is IYieldAdapter {
    address public immutable comet; // The Compound V3 Comet contract address (e.g., cUSDCv3)

    constructor(address _comet) {
        comet = _comet;
    }

    function deposit(address token, uint256 amount, bytes calldata /* data */ ) external override returns (uint256) {
        // 1. Transfer tokens from Router to this adapter
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // 2. Approve Comet to spend tokens
        IERC20(token).approve(comet, amount);

        // 3. Supply to Compound V3
        IComet(comet).supply(token, amount);

        // In Compound V3, you don't get a receipt token (cToken) for the base asset.
        // Your balance is tracked internally.
        return amount;
    }

    function withdraw(address token, uint256 amount, bytes calldata /* data */ ) external override returns (uint256) {
        // 1. Withdraw from Compound V3 to this adapter
        IComet(comet).withdraw(token, amount);

        // 2. Transfer tokens to Router (msg.sender)
        IERC20(token).transfer(msg.sender, amount);

        return amount;
    }

    function getProtocolInfo() external pure override returns (ProtocolInfo memory) {
        return ProtocolInfo({
            name: "Compound Finance",
            description: "Algorithmic Money Market",
            website: "https://compound.finance",
            icon: "compound_icon_url"
        });
    }

    function getSupplyAPY() external view returns (uint256) {
        uint256 utilization = IComet(comet).getUtilization();
        uint64 supplyRate = IComet(comet).getSupplyRate(utilization);

        // Supply Rate is per second, scaled by 1e18
        // APY = (Rate / 1e18) * SecondsPerYear * 100
        uint256 secondsPerYear = 365 * 24 * 60 * 60;
        return (uint256(supplyRate) * secondsPerYear * 100) / 1e18;
    }
}
