// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../../src/bridge/adapters/HypERC20Adapter.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock TokenHypERC20 to verify calls
contract MockTokenHypERC20 is ERC20 {
    event TransferRemoteCalled(
        uint32 destination,
        bytes32 recipient,
        uint256 amount,
        bytes data
    );

    constructor() ERC20("HypToken", "HYP") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function transferRemoteWithPayload(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes calldata _body
    ) external payable returns (bytes32 messageId) {
        emit TransferRemoteCalled(_destination, _recipient, _amount, _body);
        // Burn tokens to simulate bridge behavior (usually handled by HypERC20 parent)
        _burn(msg.sender, _amount);
        return bytes32(uint256(1));
    }
}

contract HypERC20AdapterTest is Test {
    HypERC20Adapter adapter;
    MockTokenHypERC20 token;
    address user = address(0x123);

    function setUp() public {
        adapter = new HypERC20Adapter();
        token = new MockTokenHypERC20();
        token.transfer(user, 1000 * 10 ** 18);
    }

    function testBridge() public {
        uint256 amount = 100 * 10 ** 18;
        uint32 destination = 1;
        bytes32 recipient = bytes32(uint256(uint160(address(0x456))));
        bytes memory data = "payload";

        vm.startPrank(user);
        token.approve(address(adapter), amount);

        vm.expectEmit(true, true, true, true);
        emit MockTokenHypERC20.TransferRemoteCalled(
            destination,
            recipient,
            amount,
            data
        );

        adapter.bridge(address(token), destination, recipient, amount, data);
        vm.stopPrank();

        // Verify tokens were burned (transferred to adapter then handled)
        // In our mock, adapter gets tokens then calls token contract which burns them from adapter
        // But wait, adapter does:
        // 1. IERC20(token).safeTransferFrom(msg.sender, address(this), amount); -> Adapter gets tokens
        // 2. TokenHypERC20(token).transferRemoteWithPayload(...)
        // Inside MockTokenHypERC20.transferRemoteWithPayload:
        // _burn(msg.sender, _amount); -> msg.sender is Adapter. So Adapter burns tokens.

        assertEq(token.balanceOf(address(adapter)), 0);
    }
}
