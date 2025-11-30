// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MethLabAdapter is IYieldAdapter {
    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        // Mock implementation
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        // Mock implementation
        IERC20(token).transfer(msg.sender, amount);
        return amount;
    }

    function getProtocolInfo()
        external
        pure
        override
        returns (ProtocolInfo memory)
    {
        return
            ProtocolInfo({
                name: "MethLab",
                description: "Fixed Rate/Term Lending",
                website: "https://methlab.xyz",
                icon: "methlab_icon_url"
            });
    }
}
