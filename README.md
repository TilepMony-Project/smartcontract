# Deployment Guide

This guide describes how to deploy the TilepMony smart contract system, including tokens, yield protocols, swap routers, and the main controller.

## Prerequisites

- **Foundry**: Ensure you have Foundry installed (`forge`, `cast`).
- **Environment Variables**:
  - Create a `.env` file based on `.env.example` for core deploys.
  - Create a `.env.swap` file (see `readme_swap.md`) for swap stack (Base/Mantle).
  
  Required variables:
  ```env
  PRIVATE_KEY=...
  RPC_URL=...
  ETHERSCAN_API_KEY=...
  
  # Token Addresses (required for Yield and Swap scripts)
  IDRX_ADDRESS=...
  USDC_ADDRESS=...
  USDT_ADDRESS=...
  
  # For CrossChain Token Deployment (Script reads from chains.json but needs these env vars)
  # Replace [CHAIN_PREFIX] with the prefix found in chains.json (e.g. SEPOLIA_AXELAR_GATEWAY)
  [CHAIN_PREFIX]_AXELAR_GATEWAY=...
  [CHAIN_PREFIX]_AXELAR_GAS_SERVICE=...
  ```

## Deployment Order

### 1. Deploy Tokens (If needed)

If you are on a testnet and need mock tokens:

```bash
make deploy-token
```
*Note: After deployment, update your `.env` file with the new token addresses.*

### 2. Deploy Cross-Chain Tokens (Optional)

If you need cross-chain capabilities:

```bash
forge script script/TokenCrossChain.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 3. Deploy Swap System (Base + Mantle)

This script deploys the mock Swap Routers (FusionX, MerchantMoe, Vertex), their Adapters, and the central `SwapAggregator`. It also initializes some default exchange rates (1:1 for stablecoins).

Recommended (Makefile targets):
```bash
make swap-deploy-base
make swap-deploy-mantle
# or
make swap-deploy-all
```

**Key Contracts Deployed:**
- `FusionXRouter` & `Adapter`
- `MerchantMoeRouter` & `Adapter`
- `VertexRouter` & `Adapter`
- `SwapAggregator`

### 4. Add Liquidity to Routers (Required for Swaps)

Since we are using mock routers on testnet, they need liquidity to facilitate swaps. This script mints test tokens and transfers them to the deployed routers.

```bash
make add-liquidity-router
```

### 5. Deploy Yield System

This script deploys the `YieldRouter` and adapters for MethLab, InitCapital, and Compound. It also deploys mock versions of these protocols for testing purposes.

```bash
make deploy-yield
```

**Key Contracts Deployed:**
- `YieldRouter`
- `MethLabAdapter` & `MockMethLab` vaults
- `InitCapitalAdapter` & `MockInitCore/Pools`
- `CompoundAdapter` & `MockComet` markets

### 6. Deploy Main Controller

The `MainController` orchestrates the workflows.

```bash
make deploy-controller
```

## Verification

After deployment, you can verify contract source code on Etherscan (or the relevant block explorer). The scripts include the `--verify` flag, but if it fails, you can retry using:

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME> --chain-id <CHAIN_ID> --etherscan-api-key <KEY>
```
