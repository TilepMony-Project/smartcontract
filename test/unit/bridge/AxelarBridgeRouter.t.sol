// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {AxelarBridgeRouter} from "src/bridge/routers/AxelarBridgeRouter.sol";
import {MockCrossChainToken} from "test/mocks/MockCrossChainToken.sol";

contract AxelarBridgeRouterTest is Test {
    AxelarBridgeRouter internal router;
    MockCrossChainToken internal token;

    address internal constant USER = address(0xABCD);
    string internal constant DEST_CHAIN = "mantle-sepolia";
    address internal constant DEST_CONTRACT = address(0x1234);
    address internal constant RECEIVER = address(0x9999);

    function setUp() public {
        router = new AxelarBridgeRouter(address(this));
        token = new MockCrossChainToken();
        token.mint(USER, 10 ether);
        router.setSupportedToken(address(token), true);
        deal(USER, 10 ether);
    }

    function testProviderId() public {
        bytes32 expected = keccak256("AXELAR_ROUTER");
        assertEq(router.providerId(), expected);
    }

    function testQuoteFeeMatchesFormula() public {
        uint256 amount = 5 ether;
        bytes memory extraData = hex"1234";
        uint256 expected =
            0.0005 ether + (extraData.length * 5e11) + (bytes(DEST_CHAIN).length * 1e12) + ((amount * 5) / 10_000);

        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);
        assertEq(fee, expected);
    }

    function testBridgeWithAxelarQuote() public {
        uint256 amount = 1 ether;
        bytes memory extraData = hex"01";
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);
        vm.prank(USER);
        token.approve(address(router), amount);

        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);

        assertEq(token.lastRemoteValue(), fee);
        assertEq(token.lastDestinationContract(), DEST_CONTRACT);
    }
}
