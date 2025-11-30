// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IComet} from "src/yield/interfaces/IComet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MockComet is IComet, Ownable {
    address public override baseToken;
    uint256 public utilization = 60e16; // 60%
    uint64 public supplyRate = 1000000000; // Mock rate

    constructor(address _baseToken) Ownable(msg.sender) {
        baseToken = _baseToken;
    }

    function setSupplyRate(uint64 _supplyRate) external onlyOwner {
        supplyRate = _supplyRate;
    }

    function setUtilization(uint256 _utilization) external onlyOwner {
        utilization = _utilization;
    }

    function supply(address asset, uint256 amount) external override {
        require(asset == baseToken, "Invalid asset");
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount) external override {
        require(asset == baseToken, "Invalid asset");
        IERC20(asset).transfer(msg.sender, amount);
    }

    function getSupplyRate(uint256) external view override returns (uint64) {
        return supplyRate;
    }

    function getUtilization() external view override returns (uint256) {
        return utilization;
    }
}