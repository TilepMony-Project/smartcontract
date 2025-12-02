// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AxelarExecutable} from "./axelar/AxelarExecutable.sol";
import {IAxelarGasService} from "./axelar/IAxelarGasService.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ERC20CrossChain - Minimal Axelar-style cross-chain token
/// @notice This contract illustrates a cross-chain burn-and-mint pattern.
///         It is a simplified version meant for demos and local testing.
contract MockIDRXCrossChain is ERC20, AxelarExecutable {
    IAxelarGasService public gasService;
    uint8 private _customDecimals;
    bool public initialized;

    constructor() ERC20("Mock IDRX", "mIDRX") {
        _customDecimals = 6;
    }

    function initAxelar(address gateway_, address gasReceiver_) external {
        require(!initialized, "Already initialized");
        require(gasReceiver_ != address(0), "ERC20CrossChain: zero gas");

        _setGateway(gateway_);
        gasService = IAxelarGasService(gasReceiver_);
        initialized = true;
    }

    function decimals() public view virtual override returns (uint8) {
        return _customDecimals;
    }

    /// @notice Mints tokens to the caller, intended for testing only.
    function giveMe(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    /// @notice Transfers tokens to another chain.
    /// @param destinationChain Destination chain name (example: "base-sepolia")
    /// @param destinationContract Address of the ERC20CrossChain contract on the destination chain
    /// @param amount Amount of tokens being transferred
    function transferRemote(string calldata destinationChain, address destinationContract, uint256 amount)
        public
        payable
    {
        require(msg.value > 0, "Gas payment is required");
        require(amount > 0, "Amount must be > 0");
        require(destinationContract != address(0), "Invalid destination");

        // Burn tokens on the source chain
        _burn(msg.sender, amount);

        // Payload sent to the destination chain
        bytes memory payload = abi.encode(msg.sender, amount);

        // Pay cross-chain gas (in tests, this is only recorded by MockGasService)
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this), destinationChain, _toString(destinationContract), payload, msg.sender
        );

        gateway.callContract(destinationChain, _toString(destinationContract), payload);
    }

    /// @dev Called by the Axelar Gateway (simulated by MockGateway in tests).
    function _execute(
        bytes32, /*commandId*/
        string calldata, /*sourceChain*/
        string calldata, /*sourceAddress*/
        bytes calldata payload
    ) internal override {
        (address to, uint256 amount) = abi.decode(payload, (address, uint256));
        _mint(to, amount);
    }

    /// @dev Lightweight helper to convert address -> string (hex, without the 0x prefix).
    ///      Not the most efficient implementation, but sufficient for a demo.
    function _toString(address account) internal pure returns (string memory) {
        bytes20 value = bytes20(account);
        bytes16 hexSymbols = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = hexSymbols[uint8(value[i] >> 4)];
            str[3 + i * 2] = hexSymbols[uint8(value[i] & 0x0f)];
        }
        return string(str);
    }
}
