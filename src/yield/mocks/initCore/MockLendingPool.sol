// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ILendingPool} from "../../interfaces/initCore/ILendingPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockLendingPool is ILendingPool, IERC20 {
    address public override underlyingToken;
    uint256 public supplyRate;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    constructor(address _underlyingToken) {
        underlyingToken = _underlyingToken;
    }

    function setSupplyRate(uint256 _rate) external {
        supplyRate = _rate;
    }

    function getSupplyRate_e18() external view override returns (uint256) {
        return supplyRate;
    }

    // ERC20 Mock implementation for shares
    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}
