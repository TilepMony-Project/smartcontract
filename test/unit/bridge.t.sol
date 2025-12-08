// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AxelarBridgeRouter} from "src/bridge/routers/AxelarBridgeRouter.sol";
import {BaseBridgeRouter} from "src/bridge/routers/BaseBridgeRouter.sol";
import {AxelarBridgeAdapter} from "src/bridge/adapters/AxelarBridgeAdapter.sol";
import {IBridgeAdapter} from "src/bridge/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "src/bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainToken} from "src/bridge/interfaces/ICrossChainToken.sol";

contract MockCrossChainToken is ERC20, ICrossChainToken {
    bytes32 public lastDestinationChainHash;
    address public lastDestinationContract;
    uint256 public lastRemoteAmount;
    uint256 public lastRemoteValue;
    address public lastRemoteCaller;

    constructor() ERC20("Mock Cross Chain Token", "MCCT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transferRemote(string calldata destinationChain, address destinationContract, uint256 amount)
        external
        payable
        override
    {
        require(destinationContract != address(0), "MockCrossChainToken: destination zero");
        require(amount > 0, "MockCrossChainToken: amount zero");
        require(msg.value > 0, "MockCrossChainToken: fee missing");

        lastDestinationChainHash = keccak256(bytes(destinationChain));
        lastDestinationContract = destinationContract;
        lastRemoteAmount = amount;
        lastRemoteValue = msg.value;
        lastRemoteCaller = msg.sender;
    }
}

contract BridgeTest is Test {
    AxelarBridgeRouter internal router;
    AxelarBridgeAdapter internal adapter;
    MockCrossChainToken internal token;

    address internal constant USER = address(0xBEEF);
    address internal constant AGGREGATOR = address(0xCAFE);
    string internal constant DEST_CHAIN = "base-sepolia";
    address internal constant DEST_CONTRACT = address(0x1234);
    address internal constant RECEIVER = address(0x9999);

    function setUp() public {
        router = new AxelarBridgeRouter(address(this));
        adapter = new AxelarBridgeAdapter(address(router));
        token = new MockCrossChainToken();

        token.mint(USER, 1_000_000 ether);
        deal(USER, 100 ether);
        deal(AGGREGATOR, 100 ether);
    }

    function _enableToken() internal {
        router.setSupportedToken(address(token), true);
    }

    function _computeBridgeId(uint256 nonce, address receiver_, uint256 amount, string memory chain, address dest)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(block.chainid, address(router), nonce, address(token), receiver_, amount, chain, dest)
        );
    }

    function testSetSupportedTokenToggle() public {
        assertFalse(router.supportedTokens(address(token)));

        router.setSupportedToken(address(token), true);
        assertTrue(router.supportedTokens(address(token)));

        router.setSupportedToken(address(token), false);
        assertFalse(router.supportedTokens(address(token)));
    }

    function testSetSupportedTokenRejectsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(BaseBridgeRouter.UnsupportedToken.selector, address(0)));
        router.setSupportedToken(address(0), true);
    }

    function testBridgeTokenRevertsWhenTokenUnsupported() public {
        uint256 amount = 1 ether;
        bytes memory extraData = bytes("");
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectRevert(abi.encodeWithSelector(BaseBridgeRouter.UnsupportedToken.selector, address(token)));
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeTokenRevertsInvalidAmount() public {
        _enableToken();
        bytes memory extraData = bytes("");
        uint256 fee = router.quoteFee(DEST_CHAIN, 0, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidAmount.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), 0, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeTokenRevertsInvalidReceiver() public {
        _enableToken();
        uint256 amount = 1 ether;
        bytes memory extraData = bytes("");
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidReceiver.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, address(0), extraData);
    }

    function testBridgeTokenRevertsInvalidDestination() public {
        _enableToken();
        uint256 amount = 1 ether;
        bytes memory extraData = bytes("");
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidDestination.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, "", DEST_CONTRACT, RECEIVER, extraData);

        vm.expectRevert(BaseBridgeRouter.InvalidDestination.selector);
        vm.prank(USER);
        router.bridgeToken{value: fee}(address(token), amount, DEST_CHAIN, address(0), RECEIVER, extraData);
    }

    function testBridgeTokenRevertsWhenFeeInsufficient() public {
        _enableToken();
        uint256 amount = 1 ether;
        bytes memory extraData = bytes("");
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectRevert(bytes("BaseBridgeRouter: insufficient native fee"));
        vm.prank(USER);
        router.bridgeToken{value: fee - 1}(address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData);
    }

    function testBridgeTokenSuccessFlow() public {
        _enableToken();
        uint256 amount = 10 ether;
        bytes memory extraData = abi.encode(uint16(77));
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);
        uint256 nonce = router.bridgeNonce() + 1;
        bytes32 expectedBridgeId = _computeBridgeId(nonce, RECEIVER, amount, DEST_CHAIN, DEST_CONTRACT);
        uint256 userNativeBefore = USER.balance;

        vm.prank(USER);
        token.approve(address(router), amount);

        vm.expectEmit(true, true, true, true, address(router));
        emit IBridgeRouter.BridgeInitiated(
            expectedBridgeId, USER, RECEIVER, address(token), amount, DEST_CHAIN, DEST_CONTRACT, extraData
        );

        vm.prank(USER);
        bytes32 bridgeId = router.bridgeToken{value: fee + 1 ether}(
            address(token), amount, DEST_CHAIN, DEST_CONTRACT, RECEIVER, extraData
        );

        assertEq(bridgeId, expectedBridgeId);
        assertEq(router.bridgeNonce(), nonce);
        assertEq(token.balanceOf(address(router)), amount);
        assertEq(token.balanceOf(USER), 1_000_000 ether - amount);
        assertEq(token.lastRemoteAmount(), amount);
        assertEq(token.lastRemoteValue(), fee);
        assertEq(token.lastDestinationContract(), DEST_CONTRACT);
        assertEq(token.lastDestinationChainHash(), keccak256(bytes(DEST_CHAIN)));
        assertEq(token.lastRemoteCaller(), address(router));
        assertEq(USER.balance, userNativeBefore - fee);
    }

    function testCompleteBridgeTransfersAndCannotReplay() public {
        _enableToken();
        uint256 amount = 5 ether;
        bytes32 bridgeId = bytes32(uint256(1));

        token.mint(address(router), amount);

        vm.expectEmit(true, true, false, true, address(router));
        emit IBridgeRouter.BridgeCompleted(bridgeId, address(token), RECEIVER, amount);

        router.completeBridge(address(token), RECEIVER, amount, bridgeId);

        assertEq(token.balanceOf(RECEIVER), amount);
        assertTrue(router.processedBridges(bridgeId));

        vm.expectRevert(bytes("BaseBridgeRouter: bridge already processed"));
        router.completeBridge(address(token), RECEIVER, amount, bridgeId);
    }

    function testAdapterBridgeUsesCustomPayer() public {
        _enableToken();
        uint256 amount = 2 ether;
        bytes memory extraData = hex"01";
        uint256 fee = router.quoteFee(DEST_CHAIN, amount, extraData);
        uint256 nonce = router.bridgeNonce() + 1;
        bytes32 expectedBridgeId = _computeBridgeId(nonce, RECEIVER, amount, DEST_CHAIN, DEST_CONTRACT);

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

        vm.expectEmit(true, true, true, true, address(router));
        emit IBridgeRouter.BridgeInitiated(
            expectedBridgeId, address(adapter), RECEIVER, address(token), amount, DEST_CHAIN, DEST_CONTRACT, extraData
        );

        vm.prank(AGGREGATOR);
        bytes32 bridgeId = adapter.bridge{value: fee}(params, USER);

        assertEq(bridgeId, expectedBridgeId);
        assertEq(token.balanceOf(USER), 1_000_000 ether - amount);
        assertEq(token.balanceOf(address(router)), amount);
        assertEq(token.allowance(address(adapter), address(router)), 0);
        assertEq(token.lastRemoteCaller(), address(router));
        assertEq(token.lastRemoteValue(), fee);
        assertEq(AGGREGATOR.balance, 100 ether - fee);
    }
}
