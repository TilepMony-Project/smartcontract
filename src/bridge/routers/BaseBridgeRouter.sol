// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {ICrossChainToken} from "../interfaces/ICrossChainToken.sol";

abstract contract BaseBridgeRouter is IBridgeRouter, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => bool) public supportedTokens;
    mapping(bytes32 => bool) public processedBridges;
    uint256 public bridgeNonce;

    error UnsupportedToken(address token);
    error InvalidReceiver();
    error InvalidDestination();
    error InvalidAmount();

    constructor(address initialOwner) Ownable(initialOwner) ReentrancyGuard() {}

    function setSupportedToken(address token, bool status) external onlyOwner {
        if (token == address(0)) revert UnsupportedToken(address(0));
        supportedTokens[token] = status;
        emit SupportedTokenUpdated(token, status);
    }

    function bridgeToken(
        address token,
        uint256 amount,
        string calldata destinationChain,
        address destinationContract,
        address receiver,
        bytes calldata extraData
    ) external payable override nonReentrant returns (bytes32 bridgeId) {
        if (!supportedTokens[token]) revert UnsupportedToken(token);
        if (amount == 0) revert InvalidAmount();
        if (receiver == address(0)) revert InvalidReceiver();
        if (destinationContract == address(0) || bytes(destinationChain).length == 0) revert InvalidDestination();

        uint256 requiredFee = quoteFee(destinationChain, amount, extraData);
        require(requiredFee > 0, "BaseBridgeRouter: fee must be > 0");
        require(msg.value >= requiredFee, "BaseBridgeRouter: insufficient native fee");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        ICrossChainToken(token).transferRemote{value: requiredFee}(destinationChain, destinationContract, amount);

        uint256 refund = msg.value - requiredFee;
        if (refund > 0) {
            Address.sendValue(payable(msg.sender), refund);
        }

        bridgeNonce += 1;
        bridgeId = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                bridgeNonce,
                token,
                receiver,
                amount,
                destinationChain,
                destinationContract
            )
        );

        emit BridgeInitiated(
            bridgeId, msg.sender, receiver, token, amount, destinationChain, destinationContract, extraData
        );
    }

    function completeBridge(address token, address receiver, uint256 amount, bytes32 bridgeId)
        external
        override
        onlyOwner
        nonReentrant
    {
        require(!processedBridges[bridgeId], "BaseBridgeRouter: bridge already processed");
        processedBridges[bridgeId] = true;

        IERC20(token).safeTransfer(receiver, amount);

        emit BridgeCompleted(bridgeId, token, receiver, amount);
    }

    function quoteFee(string calldata destinationChain, uint256 amount, bytes calldata extraData)
        public
        view
        virtual
        override
        returns (uint256);

    function providerId() external pure returns (bytes32) {
        return _providerId();
    }

    function _providerId() internal pure virtual returns (bytes32);
}
