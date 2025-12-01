// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {YieldRouter} from "../src/yield/YieldRouter.sol";
import {MethLabAdapter} from "../src/yield/adapters/MethLabAdapter.sol";
import {InitCapitalAdapter} from "../src/yield/adapters/InitCapitalAdapter.sol";
import {CompoundAdapter} from "../src/yield/adapters/CompoundAdapter.sol";
import {MockMethLab} from "../src/yield/mocks/MockMethLab.sol";
import {MockInitCore} from "../src/yield/mocks/initCore/MockInitCore.sol";
import {MockLendingPool} from "../src/yield/mocks/initCore/MockLendingPool.sol";
import {MockComet} from "../src/yield/mocks/MockComet.sol";

contract YieldScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address idrx = vm.envAddress("IDRX_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy YieldRouter
        YieldRouter router = new YieldRouter();
        console.log("YieldRouter deployed at:", address(router));

        // 2. Deploy & Configure MethLab (One Adapter, Multiple Vaults)
        MethLabAdapter methAdapter = new MethLabAdapter();
        console.log("MethLabAdapter deployed at:", address(methAdapter));

        _setupMethLab(methAdapter, idrx, "IDRX");
        _setupMethLab(methAdapter, usdc, "USDC");
        _setupMethLab(methAdapter, usdt, "USDT");

        router.setAdapterWhitelist(address(methAdapter), true);

        // 3. Deploy & Configure InitCapital (One Adapter, One Core, Multiple Pools)
        MockInitCore initCore = new MockInitCore();
        console.log("MockInitCore deployed at:", address(initCore));

        InitCapitalAdapter initAdapter = new InitCapitalAdapter(
            address(initCore)
        );
        console.log("InitCapitalAdapter deployed at:", address(initAdapter));

        _setupInitCapital(initAdapter, idrx, "IDRX");
        _setupInitCapital(initAdapter, usdc, "USDC");
        _setupInitCapital(initAdapter, usdt, "USDT");

        router.setAdapterWhitelist(address(initAdapter), true);

        // 4. Deploy & Configure Compound (One Adapter per Token/Market)
        _setupCompound(router, idrx, "IDRX");
        _setupCompound(router, usdc, "USDC");
        _setupCompound(router, usdt, "USDT");

        vm.stopBroadcast();
    }

    function _setupMethLab(
        MethLabAdapter adapter,
        address token,
        string memory symbol
    ) internal {
        MockMethLab vault = new MockMethLab(token);
        adapter.setVault(token, address(vault));
        console.log(
            string.concat("MethLab Vault ", symbol, " deployed at:"),
            address(vault)
        );

        // Optional: Set default APY (e.g., 10%)
        vault.setAPY(10e16);
    }

    function _setupInitCapital(
        InitCapitalAdapter adapter,
        address token,
        string memory symbol
    ) internal {
        MockLendingPool pool = new MockLendingPool(token);
        adapter.setPool(token, address(pool));
        console.log(
            string.concat("InitCapital Pool ", symbol, " deployed at:"),
            address(pool)
        );

        // Optional: Set default Supply Rate
        // 5% APY approx 1.58e9 per second
        pool.setSupplyRate(1585489599);
    }

    function _setupCompound(
        YieldRouter router,
        address token,
        string memory symbol
    ) internal {
        MockComet comet = new MockComet(token);
        CompoundAdapter adapter = new CompoundAdapter(address(comet));
        router.setAdapterWhitelist(address(adapter), true);

        console.log(
            string.concat("Compound Comet ", symbol, " deployed at:"),
            address(comet)
        );
        console.log(
            string.concat("Compound Adapter ", symbol, " deployed at:"),
            address(adapter)
        );
    }
}
