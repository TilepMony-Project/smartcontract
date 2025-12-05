// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IYieldAdapter} from "../interfaces/IYieldAdapter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IComet} from "../interfaces/IComet.sol";

contract CompoundAdapter is IYieldAdapter {
    using SafeERC20 for IERC20;

    address public immutable COMET; // The Compound V3 Comet contract address (e.g., cUSDCv3)

    constructor(address _comet) {
        COMET = _comet;
    }

    function deposit(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256, address) {
        // 1. Pull tokens from router
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Approve Compound Comet to spend tokens
        IERC20(token).forceApprove(COMET, amount);

        // 3. Supply to Compound V3
        // In Compound V3 (and our Mock), this mints `comet` tokens (shares) to `address(this)`.
        IComet(COMET).supply(token, amount);

        // 4. Forward the received shares (Comet Token) to the Router (msg.sender)
        // Note: The Comet contract address IS the token address for the shares.
        uint256 sharesBalance = IERC20(COMET).balanceOf(address(this));
        if (sharesBalance > 0) {
            IERC20(COMET).safeTransfer(msg.sender, sharesBalance);
        }

        // Return amount of underlying deposited and the share token address (comet)
        return (amount, COMET);
    }

    function withdraw(
        address token,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (uint256) {
        // 1. Withdraw from Compound V3 to this adapter
        IComet(COMET).withdraw(token, amount);

        // 2. Transfer tokens to Router (msg.sender)
        IERC20(token).safeTransfer(msg.sender, amount);

        return amount;
    }

    function getProtocolInfo()
        external
        pure
        override
        returns (ProtocolInfo memory)
    {
        return
            ProtocolInfo({
                name: "Compound Finance",
                description: "Algorithmic Money Market",
                website: "https://compound.finance",
                icon: "compound_icon_url"
            });
    }

    function getSupplyApy() external pure returns (uint256) {
        // Static APY for prototype (e.g., 3%).
        // In a real implementation, call Comet's `getSupplyRate` and convert.
        return 3e16; // 3%
    }
}
