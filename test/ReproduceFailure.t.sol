// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ReproduceFailure is Test {
    using SafeERC20 for IERC20;

    // ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed)
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    function test_logSelector() public pure {
        // Log the selector
    }

    function test_verifySelector() public pure {
        bytes4 selector = bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)"));
        console.logBytes4(selector);

        // 0xe450d38c
        assertEq(selector, bytes4(0xe450d38c));
    }
}
