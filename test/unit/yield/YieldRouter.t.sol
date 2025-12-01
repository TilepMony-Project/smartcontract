// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {YieldRouter} from "../../../src/yield/YieldRouter.sol";
import {
    InitCapitalAdapter
} from "../../../src/yield/adapters/InitCapitalAdapter.sol";
import {MethLabAdapter} from "../../../src/yield/adapters/MethLabAdapter.sol";
import {CompoundAdapter} from "../../../src/yield/adapters/CompoundAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockComet} from "../../../src/yield/mocks/MockComet.sol";
import {MockInitCore} from "../../../src/yield/mocks/initCore/MockInitCore.sol";
import {
    MockLendingPool
} from "../../../src/yield/mocks/initCore/MockLendingPool.sol";
import {MockMethLab} from "../../../src/yield/mocks/MockMethLab.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }
}

contract YieldRouterTest is Test {
    YieldRouter router;
    InitCapitalAdapter initAdapter;
    MethLabAdapter methAdapter;
    CompoundAdapter compoundAdapter;
    MockERC20 token;
    MockComet comet;
    MockInitCore initCore;
    MockLendingPool lendingPool;
    MockMethLab methVault;

    address user = address(0x1);

    function setUp() public {
        token = new MockERC20();
        comet = new MockComet(address(token));
        initCore = new MockInitCore();
        lendingPool = new MockLendingPool(address(token));
        methVault = new MockMethLab(address(token));

        router = new YieldRouter();

        methAdapter = new MethLabAdapter();
        methAdapter.setVault(address(token), address(methVault));

        compoundAdapter = new CompoundAdapter(address(comet));

        // Configure Init Adapter
        initAdapter = new InitCapitalAdapter(address(initCore));
        initAdapter.setPool(address(token), address(lendingPool));

        // Whitelist adapters
        router.setAdapterWhitelist(address(initAdapter), true);
        router.setAdapterWhitelist(address(methAdapter), true);
        router.setAdapterWhitelist(address(compoundAdapter), true);

        // Mint tokens to user
        token.mint(user, 1000 ether);
        // Mint tokens to mock comet for withdrawal
        token.mint(address(comet), 10000 ether);
        // Mint tokens to mock lending pool for withdrawal
        token.mint(address(lendingPool), 10000 ether);
    }

    function testGenericDeposit() public {
        // Test generic deposit flow using one of the adapters (e.g. MethLab)
        vm.startPrank(user);
        token.approve(address(router), 100 ether);

        uint256 amountOut = router.deposit(
            address(methAdapter),
            address(token),
            100 ether,
            ""
        );

        assertEq(amountOut, 100 ether);
        assertEq(token.balanceOf(address(methVault)), 100 ether);
        vm.stopPrank();
    }

    function testRevertDepositUnwhitelisted() public {
        vm.startPrank(user);
        token.approve(address(router), 100 ether);

        // Deploy a new random adapter that is not whitelisted
        InitCapitalAdapter randomAdapter = new InitCapitalAdapter(
            address(initCore)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                YieldRouter.AdapterNotWhitelisted.selector,
                address(randomAdapter)
            )
        );
        router.deposit(address(randomAdapter), address(token), 100 ether, "");
        vm.stopPrank();
    }
}
