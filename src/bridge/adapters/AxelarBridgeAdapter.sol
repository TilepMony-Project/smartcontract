// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBridgeAdapter} from "./IBridgeAdapter.sol";
import {IAxelarGateway} from "../interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "../interfaces/IAxelarGasService.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Adapter yang menghubungkan BridgeLayer dengan Axelar GMP.
///         - Menyimpan config chain name Axelar & receiver per dstChainId.
///         - Meng-hold token yang di-lock sebelum dipantulkan di chain tujuan.
contract AxelarBridgeAdapter is IBridgeAdapter, Ownable, ReentrancyGuard {
    IAxelarGateway public gateway;
    IAxelarGasService public gasService;

    // mapping EVM chainId -> Axelar chain name (e.g. 84532 -> "base-sepolia")
    mapping(uint256 => string) public chainIdToAxelarName;

    // mapping EVM chainId -> destination receiver contract (string address)
    mapping(uint256 => string) public dstChainIdToReceiver;

    event DestinationSet(uint256 indexed chainId, string axelarChain, string receiver);

    constructor(address _gateway, address _gasService) Ownable(msg.sender) {
        require(_gateway != address(0), "AxelarAdapter: zero gateway");
        require(_gasService != address(0), "AxelarAdapter: zero gas");
        gateway = IAxelarGateway(_gateway);
        gasService = IAxelarGasService(_gasService);
    }

    /// @notice Set konfigurasi destinasi utk chain tertentu.
    function setDestination(
        uint256 chainId,
        string calldata axelarChain,
        string calldata receiver
    ) external onlyOwner {
        chainIdToAxelarName[chainId] = axelarChain;
        dstChainIdToReceiver[chainId] = receiver;
        emit DestinationSet(chainId, axelarChain, receiver);
    }

    /// @notice Fungsi yang dipanggil oleh BridgeLayer.
    ///         Di sini token di-lock dan pesan cross-chain dikirim.
    function bridge(
        address token,
        uint256 amount,
        uint256 dstChainId,
        address recipient,
        bytes calldata extraData
    ) external payable override nonReentrant {
        string memory dstChain = chainIdToAxelarName[dstChainId];
        string memory receiver = dstChainIdToReceiver[dstChainId];

        require(bytes(dstChain).length > 0, "AxelarAdapter: CHAIN_NOT_SET");
        require(bytes(receiver).length > 0, "AxelarAdapter: RECEIVER_NOT_SET");
        require(amount > 0, "AxelarAdapter: ZERO_AMOUNT");
        require(recipient != address(0), "AxelarAdapter: ZERO_RECIPIENT");

        // Lock token di adapter (kontrak ini)
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // payload yang dikirim ke receiver di destination chain
        bytes memory payload = abi.encode(token, amount, recipient, extraData);

        // Bayar gas cross-chain (opsional tapi recommended)
        if (msg.value > 0) {
            gasService.payNativeGasForContractCall{value: msg.value}(
                address(this),
                dstChain,
                receiver,
                payload,
                msg.sender
            );
        }

        // Kirim GMP
        gateway.callContract(dstChain, receiver, payload);
    }
}
