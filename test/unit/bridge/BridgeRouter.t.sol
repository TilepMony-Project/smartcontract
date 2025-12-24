// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../../src/bridge/BridgeRouter.sol";
import "../../../src/bridge/interfaces/IBridgeAdapter.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract MockBridgeAdapter is IBridgeAdapter {
    event BridgeCalled(
        address token,
        uint32 destination,
        bytes32 recipient,
        uint256 amount,
        bytes data
    );

    function bridge(
        address token,
        uint32 destination,
        bytes32 recipient,
        uint256 amount,
        bytes calldata data
    ) external payable override {
        emit BridgeCalled(token, destination, recipient, amount, data);
    }
}

contract BridgeRouterTest is Test {
    BridgeRouter router;
    MockERC20 token;
    MockBridgeAdapter adapter;
    address user = address(0x123);
    address owner = address(this);

    function setUp() public {
        router = new BridgeRouter(owner);
        token = new MockERC20();
        adapter = new MockBridgeAdapter();
        token.transfer(user, 1000 * 10 ** 18);
    }

    function testSetAdapter() public {
        router.setAdapter(address(token), address(adapter));
        assertEq(router.adapters(address(token)), address(adapter));
    }

    function testSetAdapterOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        router.setAdapter(address(token), address(adapter));
    }

    function testBridge() public {
        router.setAdapter(address(token), address(adapter));

        uint256 amount = 100 * 10 ** 18;
        uint32 destination = 1;
        bytes32 recipient = bytes32(uint256(uint160(address(0x456))));
        bytes memory data = "payload";

        vm.startPrank(user);
        token.approve(address(router), amount);

        vm.expectEmit(true, true, true, true);
        emit MockBridgeAdapter.BridgeCalled(
            address(token),
            destination,
            recipient,
            amount,
            data
        );

        router.bridge(address(token), destination, recipient, amount, data);
        vm.stopPrank();

        // Check if tokens were moved to adapter (MockBridgeAdapter doesn't pull tokens,
        // but real adapter would. BridgeRouter approves adapter)
        // Check router allowance to adapter
        assertEq(token.allowance(address(router), address(adapter)), amount);
    }

    function testBridgeNoAdapter() public {
        vm.prank(user);
        vm.expectRevert("Adapter not found for token");
        router.bridge(address(token), 1, bytes32(0), 100, "");
    }
}
