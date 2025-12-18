// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";
import {CompoundAdapter} from "../../../src/yield/adapters/CompoundAdapter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockComet} from "../../../src/yield/mocks/MockComet.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}

    contract YieldRouterRefactorVerification is Test {
        YieldRouter router;
        CompoundAdapter compoundAdapter;
        MockERC20 token;
        MockComet comet;

        address user = address(0x1);

        function setUp() public {
            token = new MockERC20();
            comet = new MockComet(address(token), "Compound Mock", "cMOCK");
            router = new YieldRouter();

            compoundAdapter = new CompoundAdapter(address(comet));

            // Whitelist adapter
            router.setAdapterWhitelist(address(compoundAdapter), true);

            // Mint tokens to user
            token.mint(user, 1000 ether);
            // Mint tokens to MockComet for withdrawals (mock liquidity)
            token.mint(address(comet), 10000 ether);
        }

        function testCompoundDepositMintsShares() public {
            vm.startPrank(user);
            token.approve(address(router), 100 ether);

            // Record balances before
            uint256 userShareBalanceBefore = comet.balanceOf(user);

            // Deposit
            router.deposit(address(compoundAdapter), address(token), 100 ether, "");

            // Record balances after
            uint256 userShareBalanceAfter = comet.balanceOf(user);
            uint256 adapterShareBalanceAfter = comet.balanceOf(address(compoundAdapter));

            // Verify shares were forwarded to the User (MockComet -> Adapter -> Router -> User)
            assertEq(userShareBalanceAfter - userShareBalanceBefore, 100 ether, "User should receive shares");
            assertEq(adapterShareBalanceAfter, 0, "Adapter should NOT hold shares");

            vm.stopPrank();
        }

        function testCompoundWithdrawBurnsShares() public {
            // Setup scenarios: User has already deposited
            vm.startPrank(user);
            token.approve(address(router), 100 ether);
            router.deposit(address(compoundAdapter), address(token), 100 ether, "");

            // User must approve shares for Router to pull
            comet.approve(address(router), 50 ether);

            uint256 userShareBalanceBefore = comet.balanceOf(user);
            uint256 userTokenBalanceBefore = token.balanceOf(user);

            // Withdraw half
            router.withdraw(
                address(compoundAdapter),
                address(comet), // Share Token
                address(token), // Underlying
                50 ether,
                ""
            );

            uint256 userShareBalanceAfter = comet.balanceOf(user);
            uint256 userTokenBalanceAfter = token.balanceOf(user);

            // Verify shares were pulled/burned from User
            assertEq(userShareBalanceBefore - userShareBalanceAfter, 50 ether, "User shares should decrease");
            // Verify user got tokens back
            assertEq(userTokenBalanceAfter - userTokenBalanceBefore, 50 ether, "User should receive underlying");

            vm.stopPrank();
        }
    }
