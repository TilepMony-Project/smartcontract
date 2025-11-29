// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BridgeLayer} from "src/bridge/BridgeLayer.sol";
import {IBridgeAdapter} from "src/bridge/adapters/IBridgeAdapter.sol";
import {AxelarBridgeAdapter} from "src/bridge/adapters/AxelarBridgeAdapter.sol";
import {IAxelarGateway} from "src/bridge/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "src/bridge/interfaces/IAxelarGasService.sol";
import {MockToken} from "src/token/MockToken.sol";

contract MockBridgeAdapter is IBridgeAdapter {
    address public lastToken;
    uint256 public lastAmount;
    uint256 public lastDstChainId;
    address public lastRecipient;
    bytes public lastExtraData;
    address public lastCaller;
    uint256 public lastValue;
    uint256 public bridgeCallCount;

    event BridgeCalled(
        address token,
        uint256 amount,
        uint256 dstChainId,
        address recipient,
        bytes extraData,
        uint256 value,
        address caller
    );

    function bridge(
        address token,
        uint256 amount,
        uint256 dstChainId,
        address recipient,
        bytes calldata extraData
    ) external payable override {
        lastToken = token;
        lastAmount = amount;
        lastDstChainId = dstChainId;
        lastRecipient = recipient;
        lastExtraData = extraData;
        lastCaller = msg.sender;
        lastValue = msg.value;
        bridgeCallCount++;

        emit BridgeCalled(token, amount, dstChainId, recipient, extraData, msg.value, msg.sender);
    }
}

contract MockGateway is IAxelarGateway {
    string public lastDestinationChain;
    string public lastContractAddress;
    bytes public lastPayload;
    uint256 public callCount;

    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external {
        lastDestinationChain = destinationChain;
        lastContractAddress = contractAddress;
        lastPayload = payload;
        callCount++;
    }
}

contract MockGasService is IAxelarGasService {
    address public lastSenderParam;
    string public lastDestinationChain;
    string public lastDestinationAddress;
    bytes public lastPayload;
    address public lastRefundAddress;
    uint256 public lastValue;
    uint256 public callCount;

    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable override {
        lastSenderParam = sender;
        lastDestinationChain = destinationChain;
        lastDestinationAddress = destinationAddress;
        lastPayload = payload;
        lastRefundAddress = refundAddress;
        lastValue = msg.value;
        callCount++;
    }
}

contract BridgeLayerTest is Test {
    BridgeLayer internal bridgeLayer;
    MockBridgeAdapter internal adapter;
    address internal user = address(0xBEEF);
    address internal token = address(0x1111);

    function setUp() public {
        bridgeLayer = new BridgeLayer();
        adapter = new MockBridgeAdapter();
        vm.deal(user, 100 ether);
    }

    function testOwnerCanSetAdapter() public {
        vm.expectEmit(true, false, false, true, address(bridgeLayer));
        emit BridgeLayer.AdapterUpdated(address(adapter));

        bridgeLayer.setAxelarAdapter(address(adapter));
        assertEq(bridgeLayer.axelarAdapter(), address(adapter));
    }

    function testSetAdapterRevertsForNonOwner() public {
        address attacker = address(0xA11CE);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker)
        );
        bridgeLayer.setAxelarAdapter(address(adapter));
    }

    function testBridgeRevertsWhenNoAdapter() public {
        vm.expectRevert("BridgeLayer: NO_ADAPTER");
        vm.prank(user);
        bridgeLayer.bridge(token, 1 ether, 84532, user, "");
    }

    function testBridgeForwardsCallAndEmitsEvent() public {
        bridgeLayer.setAxelarAdapter(address(adapter));

        uint256 amount = 5 ether;
        uint256 dstChainId = 84532;
        address recipient = address(0xCAFE);
        bytes memory extraData = hex"1234";
        uint256 nativeValue = 0.25 ether;

        vm.expectEmit(true, true, true, true, address(bridgeLayer));
        emit BridgeLayer.BridgeRequested(token, amount, dstChainId, recipient);

        vm.prank(user);
        bridgeLayer.bridge{value: nativeValue}(token, amount, dstChainId, recipient, extraData);

        assertEq(adapter.bridgeCallCount(), 1);
        assertEq(adapter.lastToken(), token);
        assertEq(adapter.lastAmount(), amount);
        assertEq(adapter.lastDstChainId(), dstChainId);
        assertEq(adapter.lastRecipient(), recipient);
        assertEq(keccak256(adapter.lastExtraData()), keccak256(extraData));
        assertEq(adapter.lastCaller(), address(bridgeLayer));
        assertEq(adapter.lastValue(), nativeValue);
    }
}

contract AxelarBridgeAdapterTest is Test {
    AxelarBridgeAdapter internal adapter;
    MockGateway internal gateway;
    MockGasService internal gasService;
    MockToken internal token;
    address internal user = address(0xA11CE);
    address internal recipient = address(0xC0FFEE);
    uint256 internal constant DST_CHAIN_ID = 84532;
    string internal constant AXELAR_CHAIN = "base-sepolia";
    string internal constant RECEIVER = "receiver-contract";

    function setUp() public {
        gateway = new MockGateway();
        gasService = new MockGasService();
        adapter = new AxelarBridgeAdapter(address(gateway), address(gasService));
        token = new MockToken("Mock Token", "MOCK", 18, 1_000_000 ether);
        token.transfer(user, 1_000 ether);
        vm.deal(user, 100 ether);
    }

    function testSetDestinationOnlyOwner() public {
        vm.expectEmit(true, true, true, true, address(adapter));
        emit AxelarBridgeAdapter.DestinationSet(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);

        address attacker = address(0xDEAD);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker)
        );
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);
    }

    function testBridgeRevertsWhenChainNotConfigured() public {
        vm.prank(user);
        vm.expectRevert("AxelarAdapter: CHAIN_NOT_SET");
        adapter.bridge(address(token), 1 ether, DST_CHAIN_ID, recipient, "");
    }

    function testBridgeRevertsWhenReceiverMissing() public {
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, "");

        vm.prank(user);
        vm.expectRevert("AxelarAdapter: RECEIVER_NOT_SET");
        adapter.bridge(address(token), 1 ether, DST_CHAIN_ID, recipient, "");
    }

    function testBridgeRevertsOnZeroAmount() public {
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);

        vm.prank(user);
        vm.expectRevert("AxelarAdapter: ZERO_AMOUNT");
        adapter.bridge(address(token), 0, DST_CHAIN_ID, recipient, "");
    }

    function testBridgeRevertsOnZeroRecipient() public {
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);

        vm.prank(user);
        vm.expectRevert("AxelarAdapter: ZERO_RECIPIENT");
        adapter.bridge(address(token), 1 ether, DST_CHAIN_ID, address(0), "");
    }

    function _prepareAllowance(uint256 amount) internal {
        vm.startPrank(user);
        token.approve(address(adapter), amount);
        vm.stopPrank();
    }

    function testBridgeTransfersTokenPaysGasAndCallsGateway() public {
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);

        uint256 amount = 10 ether;
        uint256 gasValue = 0.5 ether;
        bytes memory extraData = abi.encode("hello");
        bytes memory expectedPayload = abi.encode(address(token), amount, recipient, extraData);

        _prepareAllowance(amount);

        vm.prank(user);
        adapter.bridge{value: gasValue}(address(token), amount, DST_CHAIN_ID, recipient, extraData);

        assertEq(token.balanceOf(address(adapter)), amount);
        assertEq(gateway.callCount(), 1);
        assertEq(gateway.lastContractAddress(), RECEIVER);
        assertEq(gateway.lastDestinationChain(), AXELAR_CHAIN);
        assertEq(keccak256(gateway.lastPayload()), keccak256(expectedPayload));

        assertEq(gasService.callCount(), 1);
        assertEq(gasService.lastValue(), gasValue);
        assertEq(gasService.lastSenderParam(), address(adapter));
        assertEq(gasService.lastRefundAddress(), user);
        assertEq(gasService.lastDestinationChain(), AXELAR_CHAIN);
        assertEq(gasService.lastDestinationAddress(), RECEIVER);
        assertEq(keccak256(gasService.lastPayload()), keccak256(expectedPayload));
    }

    function testBridgeSkipsGasPaymentWhenNoValue() public {
        adapter.setDestination(DST_CHAIN_ID, AXELAR_CHAIN, RECEIVER);

        uint256 amount = 2 ether;
        _prepareAllowance(amount);

        vm.prank(user);
        adapter.bridge(address(token), amount, DST_CHAIN_ID, recipient, "");

        assertEq(gasService.callCount(), 0);
        assertEq(token.balanceOf(address(adapter)), amount);
    }
}
