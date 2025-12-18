// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenHypERC20} from "../../src/token/TokenHypERC20.sol";
import {
    MockMailbox,
    MockInterchainGasPaymaster,
    MockInterchainSecurityModule
} from "../../test/mocks/HyperlaneStubs.sol";

abstract contract TokenHypTestBase is Test {
    uint32 private _domainCounter = 1;

    function _deployToken(string memory name, string memory symbol) internal returns (TokenHypERC20) {
        MockMailbox mailbox = new MockMailbox(_domainCounter++);
        MockInterchainGasPaymaster igp = new MockInterchainGasPaymaster();
        MockInterchainSecurityModule ism = new MockInterchainSecurityModule();

        return new TokenHypERC20(
            address(mailbox),
            6,
            name,
            symbol,
            address(igp),
            address(ism),
            address(this),
            0,
            address(this)
        );
    }

    function _mintTo(TokenHypERC20 token, address account, uint256 amount) internal {
        vm.prank(account);
        token.giveMe(amount);
    }
}
