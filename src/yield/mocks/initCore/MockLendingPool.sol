// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ILendingPool} from "../../interfaces/initCore/ILendingPool.sol";
import {MockERC20} from "../MockERC20.sol";

contract MockLendingPool is ILendingPool, MockERC20 {
    address public override underlyingToken;
    uint256 public supplyRate;
    uint256 public exchangeRate = 1e18; // Default 1:1

    constructor(
        address _underlyingToken,
        string memory name,
        string memory symbol
    ) MockERC20(name, symbol, 18) {
        underlyingToken = _underlyingToken;
    }

    function setSupplyRate(uint256 _rate) external {
        supplyRate = _rate;
    }

    function setExchangeRate(uint256 _rate) external {
        exchangeRate = _rate;
    }

    function getSupplyRateE18() external view override returns (uint256) {
        return supplyRate;
    }
}
