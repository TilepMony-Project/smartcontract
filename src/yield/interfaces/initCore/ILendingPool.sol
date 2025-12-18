// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILendingPool {
    function getSupplyRateE18() external view returns (uint256);
    function underlyingToken() external view returns (address);
}
