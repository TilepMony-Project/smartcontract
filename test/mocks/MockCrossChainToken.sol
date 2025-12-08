// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ICrossChainToken} from "src/bridge/interfaces/ICrossChainToken.sol";

/**
 * @dev Lightweight cross-chain token mock that records the last transferRemote call.
 */
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
