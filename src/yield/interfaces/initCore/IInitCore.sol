// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IInitCore {
    function mintTo(address pool, address receiver) external returns (uint256 shares);
    function burnTo(address pool, address receiver) external returns (uint256 amount);
}
