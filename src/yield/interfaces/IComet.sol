// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IComet {
    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function getSupplyRate(uint256 utilization) external view returns (uint64);
    function getUtilization() external view returns (uint256);
    function baseToken() external view returns (address);
    function exchangeRate() external view returns (uint256);
}
