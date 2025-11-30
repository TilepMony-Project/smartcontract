// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Token ERC20 sederhana berbasis OpenZeppelin, dengan decimals custom.
contract MockToken is ERC20, Ownable {
    uint8 private _decimalsValue;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply, address initialOwner)
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    {
        _decimalsValue = decimals_;
        _mint(initialOwner, initialSupply);
    }

    function decimals() public view override returns (uint8) {
        return _decimalsValue;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
