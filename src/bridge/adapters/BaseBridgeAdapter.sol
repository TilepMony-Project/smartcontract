// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

abstract contract BaseBridgeAdapter is IBridgeAdapter {
    using SafeERC20 for IERC20;

    error InvalidRouter();

    IBridgeRouter public immutable ROUTER;

    constructor(address router_) {
        if (router_ == address(0)) revert InvalidRouter();
        ROUTER = IBridgeRouter(router_);
    }

    function bridge(BridgeParams calldata params, address from)
        external
        payable
        virtual
        override
        returns (bytes32 bridgeId)
    {
        address payer = from == address(0) ? msg.sender : from;
        IERC20 token = IERC20(params.token);

        token.safeTransferFrom(payer, address(this), params.amount);
        token.safeIncreaseAllowance(address(ROUTER), params.amount);

        bridgeId = ROUTER.bridgeToken{value: msg.value}(
            params.token,
            params.amount,
            params.destinationChain,
            params.destinationAddress,
            params.receiver,
            params.extraData
        );
    }
}
