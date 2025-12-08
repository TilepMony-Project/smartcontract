// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ReproduceFailure is Test {
    using SafeERC20 for IERC20;

    // ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed)
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    function test_logSelector() public pure {
        // Log the selector
    }

    function test_verifySelector() public {
        bytes4 selector = bytes4(
            keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")
        );
        console.logBytes4(selector);

        // 0xfb8f41b2
        assertEq(selector, bytes4(0xfb8f41b2));
    }
}
