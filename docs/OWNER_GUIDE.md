# Owner Guide

This guide details the administrative actions available to the contract owner.

## MainController

### Ownership
- The `MainController` is owned by the account that deployed it (or specified in the script).
- Only the owner can execute certain administrative functions (inheriting from `Ownable`).

### Updates
- Currently, `MainController` logic is immutable. To upgrade, you would typically deploy a new controller and migrate.

## Swap System

### SwapAggregator
- **Add Adapter**: `addTrustedAdapter(address _adapterAddress)`
- **Remove Adapter**: `removeTrustedAdapter(address _adapterAddress)`

### Mock Routers (FusionX, MerchantMoe, Vertex)
These are mock routers used for testing. In a real production scenario, these would likely be immutable interfaces to existing DEXs.

- **Update Exchange Rate**: 
  - Call `setRate(address tokenIn, address tokenOut, uint256 rate)`
  - `rate` is scaled by 1e18. (e.g., 1.0 = 1000000000000000000)

### Liquidity Provisioning (Required for Simulation)
Since these are mock routers, you must provide them with liquidity to enable swaps.
- **Add Liquidity**: Run `make add-liquidity-router`

## Yield System

### YieldRouter
- **Whitelist Adapter**: `setAdapterWhitelist(address adapter, bool status)`

### Protocol Mocks (Testing Environment)

#### MockMethLab (Vault)
- **Update APY**: `setApy(uint256 _apy)`
  - Format: 1e18 scale (e.g., 0.1e18 = 10% APY).

#### MockInitCore / MockLendingPool (InitCapital)
- **Update Supply Rate**: `setSupplyRate(uint256 _rate)`
  - Format: Rate per second (e.g., for 5% APY ≈ 1.58e9 per second).

#### MockComet (Compound)
- **Update Supply Rate**: `setSupplyRate(uint64 supplyRate_)`
  - Format: Rate per second.
