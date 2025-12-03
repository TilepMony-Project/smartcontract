// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AxelarBridgeRouter} from "src/bridge/routers/AxelarBridgeRouter.sol";
import {AxelarBridgeAdapter} from "src/bridge/adapters/AxelarBridgeAdapter.sol";
import {IBridgeAdapter} from "src/bridge/interfaces/IBridgeAdapter.sol";
import {MockCrossChainToken} from "test/mocks/MockCrossChainToken.sol";

contract AxelarBridgeAdapterTest is Test {
    AxelarBridgeRouter internal router;
    AxelarBridgeAdapter internal adapter;
    MockCrossChainToken internal token;

    address internal constant USER = address(0xBEEF);
    address internal constant AGGREGATOR = address(0xCAFE);
    string internal constant DEST_CHAIN = "mantle-sepolia";
    address internal constant DEST_CONTRACT = address(0x5555);
    address internal constant RECEIVER = address(0x8888);

    function setUp() public {
        router = new AxelarBridgeRouter(address(this));
        adapter = new AxelarBridgeAdapter(address(router));
        token = new MockCrossChainToken();

        router.setSupportedToken(address(token), true);
        token.mint(USER, 1_000 ether);
        deal(USER, 100 ether);
        deal(AGGREGATOR, 50 ether);
    }

    function testBridgeFromUserDirectly() public {
        uint256 amount = 10 ether;
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        IBridgeAdapter.BridgeParams memory params = IBridgeAdapter.BridgeParams({
            token: address(token),
            amount: amount,
            destinationChain: DEST_CHAIN,
            destinationAddress: DEST_CONTRACT,
            receiver: RECEIVER,
            extraData: extraData
        });

        vm.prank(USER);
        token.approve(address(adapter), amount);

        vm.prank(USER);
        adapter.bridge{value: fee}(params, address(0));

        assertEq(token.balanceOf(USER), 1_000 ether - amount);
        assertEq(token.balanceOf(address(router)), amount);
        assertEq(token.allowance(address(adapter), address(router)), 0);
        assertEq(token.lastRemoteValue(), fee);
    }

    function testBridgeFromAggregatorWithCustomPayer() public {
        uint256 amount = 5 ether;
        bytes memory extraData = hex"01";
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        IBridgeAdapter.BridgeParams memory params = IBridgeAdapter.BridgeParams({
            token: address(token),
            amount: amount,
            destinationChain: DEST_CHAIN,
            destinationAddress: DEST_CONTRACT,
            receiver: RECEIVER,
            extraData: extraData
        });

        vm.prank(USER);
        token.approve(address(adapter), amount);

        vm.prank(AGGREGATOR);
        adapter.bridge{value: fee}(params, USER);

        assertEq(token.balanceOf(USER), 1_000 ether - amount);
        assertEq(token.balanceOf(address(router)), amount);
        assertEq(token.lastRemoteValue(), fee);
        assertEq(AGGREGATOR.balance, 50 ether - fee);
    }
}
