// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {BaseBridgeRouter} from "src/bridge/routers/BaseBridgeRouter.sol";
import {IBridgeRouter} from "src/bridge/interfaces/IBridgeRouter.sol";
import {IBridgeRouter} from "src/bridge/interfaces/IBridgeRouter.sol";
// import {IBridgeAdapter} from "src/bridge/interfaces/IBridgeAdapter.sol";
import {MockCrossChainToken} from "test/mocks/MockCrossChainToken.sol";

contract MockBridgeRouter is BaseBridgeRouter {
    uint256 public constant BASE_FEE = 0.0004 ether;

    constructor(address owner_) BaseBridgeRouter(owner_) {}

    function quoteFee(string calldata destinationChain, uint256 amount, bytes calldata extraData)
        public
        pure
        override
        returns (uint256)
    {
        return BASE_FEE + (amount / 1_000) + bytes(destinationChain).length * 1e9 + extraData.length * 1e8;
    }

    function _providerId() internal pure override returns (bytes32) {
        return keccak256("MOCK_ROUTER");
    }
}

contract BaseBridgeRouterTest is Test {
    MockBridgeRouter internal router;
    MockCrossChainToken internal token;

    address internal constant USER = address(0xBEEF);
    address internal constant RECEIVER = address(0x7777);
    string internal constant DEST_CHAIN = "base-sepolia";
    address internal constant DEST_CONTRACT = address(0x1234);

    function setUp() public {
        router = new MockBridgeRouter(address(this));
        token = new MockCrossChainToken();

        token.mint(USER, 1_000_000 ether);
        deal(USER, 100 ether);
    }

    function _enableToken() internal {
        router.setSupportedToken(address(token), true);
    }

    function _computeBridgeId(
        uint256 nonce,
        address receiver_,
        uint256 amount,
        string memory destinationChain,
        address destContract
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                block.chainid, address(router), nonce, address(token), receiver_, amount, destinationChain, destContract
            )
        );
    }

    function testSetSupportedTokenToggle() public {
        assertFalse(router.supportedTokens(address(token)));

        router.setSupportedToken(address(token), true);
        assertTrue(router.supportedTokens(address(token)));

        router.setSupportedToken(address(token), false);
        assertFalse(router.supportedTokens(address(token)));
    }

    function testSetSupportedTokenRejectsZero() public {
        vm.expectRevert(abi.encodeWithSelector(BaseBridgeRouter.UnsupportedToken.selector, address(0)));
        router.setSupportedToken(address(0), true);
    }

    function testBridgeRevertsUnsupportedToken() public {
        uint256 amount = 1 ether;
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeRouter.UnsupportedToken.selector, address(token)));
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeRevertsZeroAmount() public {
        _enableToken();
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, 0, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidAmount.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), 0, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeRevertsInvalidReceiver() public {
        _enableToken();
        uint256 amount = 1 ether;
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidReceiver.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, address(0), extraData);
    }

    function testBridgeRevertsInvalidDestination() public {
        _enableToken();
        uint256 amount = 1 ether;
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidDestination.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, "", DEST_CONTRACT, RECEIVER, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidDestination.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, address(0), RECEIVER, extraData);
    }

    function testBridgeRevertsWhenFeeInsufficient() public {
        _enableToken();
        uint256 amount = 2 ether;
        bytes memory extraData;
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectRevert(bytes("BaseBridgeRouter: insufficient native fee"));
        vm.prank(USER);
        router.bridgeToken{value: fee - 1}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeSuccessFlow() public {
        _enableToken();
        uint256 amount = 10 ether;
        bytes memory extraData = abi.encode(uint16(3));
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);
        uint256 nonce = router.bridgeNonce() + 1;
        bytes32 expectedBridgeId = _computeBridgeId(nonce, RECEIVER, amount, DEST_CHAIN, DEST_CONTRACT);
        uint256 nativeBefore = USER.balance;

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectEmit(true, true, true, true, address(router));
        emit IBridgeRouter.BridgeInitiated(
            expectedBridgeId, USER, RECEIVER, address(token), amount, DEST_CHAIN, DEST_CONTRACT, extraData
        );

        vm.prank(USER);
        bytes32 bridgeId = router.bridgeToken{value: fee + 0.1 ether}(
            address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData
        );

        assertEq(bridgeId, expectedBridgeId);
        assertEq(router.bridgeNonce(), nonce);
        assertEq(token.balanceOf(address(router)), amount);
        assertEq(token.lastRemoteAmount(), amount);
        assertEq(token.lastRemoteValue(), fee);
        assertEq(token.lastDestinationContract(), DEST_CONTRACT);
        assertEq(token.lastDestinationChainHash(), keccak256(bytes(DEST_CHAIN)));
        assertEq(token.lastRemoteCaller(), address(router));
        assertEq(USER.balance, nativeBefore - fee);
    }

    function testCompleteBridgeTransfersAndBlocksReplay() public {
        _enableToken();
        uint256 amount = 5 ether;
        bytes32 bridgeId = bytes32(uint256(777));

        token.mint(address(router), amount);

        vm.expectEmit(true, true, false, true, address(router));
        emit IBridgeRouter.BridgeCompleted(bridgeId, address(token), RECEIVER, amount);

        router.completeBridge(address(token), RECEIVER, amount, bridgeId);

        assertEq(token.balanceOf(RECEIVER), amount);
        assertTrue(router.processedBridges(bridgeId));

        vm.expectRevert(bytes("BaseBridgeRouter: bridge already processed"));
        router.completeBridge(address(token), RECEIVER, amount, bridgeId);
    }
}
