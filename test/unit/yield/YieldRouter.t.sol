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

    address user = address(0x1);

    function setUp() public {
        token = new MockERC20();
        comet = new MockComet(address(token));
        initCore = new MockInitCore();
        lendingPool = new MockLendingPool(address(token));

        router = new YieldRouter();
        
        methAdapter = new MethLabAdapter();
        
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

    function testDepositInitCapital() public {
        vm.startPrank(user);
        token.approve(address(router), 100 ether);

        console.log("Initial User Balance:", token.balanceOf(user));
        console.log(
            "Initial LendingPool Balance:",
            token.balanceOf(address(lendingPool))
        );

        uint256 amountOut = router.deposit(
            address(initAdapter),
            address(token),
            100 ether,
            ""
        );

        console.log("Amount Deposited:", uint256(100 ether));
        console.log("Amount Out (Shares):", amountOut);
        console.log("Final User Balance:", token.balanceOf(user));
        console.log(
            "Final LendingPool Balance:",
            token.balanceOf(address(lendingPool))
        );

        // In the new flow:
        // 1. Router -> Adapter
        // 2. Adapter -> LendingPool
        // 3. Adapter calls InitCore.mintTo
        // 4. InitCore returns shares (mocked as 100 ether)

        assertEq(amountOut, 100 ether);
        // Token should be in LendingPool
        assertEq(
            token.balanceOf(address(lendingPool)),
            100 ether + 10000 ether
        );
        vm.stopPrank();
    }

    function testDepositMethLab() public {
        vm.startPrank(user);
        token.approve(address(router), 100 ether);

        uint256 amountOut = router.deposit(
            address(methAdapter),
            address(token),
            100 ether,
            ""
        );

        assertEq(amountOut, 100 ether);
        assertEq(token.balanceOf(address(methAdapter)), 100 ether);
        vm.stopPrank();
    }

    function testDepositCompound() public {
        vm.startPrank(user);
        token.approve(address(router), 100 ether);

        console.log("Initial User Balance:", token.balanceOf(user));
        console.log("Initial Comet Balance:", token.balanceOf(address(comet)));

        uint256 amountOut = router.deposit(
            address(compoundAdapter),
            address(token),
            100 ether,
            ""
        );

        console.log("Amount Out:", amountOut);
        console.log("Final User Balance:", token.balanceOf(user));
        console.log("Final Comet Balance:", token.balanceOf(address(comet)));

        assertEq(amountOut, 100 ether);
        // Adapter supplies to Comet, so adapter balance is 0, Comet balance is 100 ether
        assertEq(token.balanceOf(address(comet)), 100 ether + 10000 ether); // 10000 was initial mint
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

    function testCompoundAPY() public {
        // MockComet default supply rate is 1000000000 (1e9) per second
        // APY = (1e9 * 31536000 * 100) / 1e18 = 3153600000 / 1e9 = 3.15%
        // Wait, 1e9 per second is huge. Let's check MockComet again.
        // MockComet: uint64 public supplyRate = 1000000000;
        // 1e9 per second.
        // 1e9 * 365 * 24 * 3600 = 31,536,000 * 1e9 = 3.15 * 10^16
        // Divided by 1e18 -> 0.0315 -> * 100 -> 3.15%

        uint256 apy = compoundAdapter.getSupplyAPY();
        console.log("Compound APY:", apy);
        assertGt(apy, 0);
    }

    function testInitCapitalAPY() public {
        // Set rate in mock lending pool
        // 5% APY -> 1.58e-9 per second -> 1585489599 scaled by 1e18
        uint256 targetRate = 1585489599;
        lendingPool.setSupplyRate(targetRate);

        uint256 apy = initAdapter.getSupplyAPY(address(token));
        console.log("Init Capital APY:", apy);
        // Should be approx 5% (5)
        assertApproxEqAbs(apy, 5, 1);
    }
}
