# Mock Token Deployment & Usage

This document explains how to deploy the mock tokens (mIDRX, mUSDT, mUSDC) and use them in the bridge test.

## Deployment

To deploy the mock tokens, you need to run the deployment script on **each network** you intend to support (e.g., Mantle Sepolia AND Base Sepolia).

### Prerequisites

1. Configure your `.env` file with:
    - `PRIVATE_KEY`
    - `RPC_URL` (Default for Mantle Sepolia)
    - `RPC_URL_BASE` (For Base Sepolia)
    - `ETHERSCAN_API_KEY` (required for verification)
2. Ensure you have native gas tokens on each chain.

### Step-by-Step Multi-Chain Deployment

**1. Deploy to Mantle Sepolia:**

```bash
source .env
forge script script/DeployMockToken.sol:DeployMockToken --rpc-url $RPC_URL --broadcast --verify
```

**2. Deploy to Base Sepolia:**

```bash
source .env
forge script script/DeployMockToken.sol:DeployMockToken --rpc-url $RPC_URL_BASE --broadcast --verify
```

*Note: Ensure `RPC_URL` and `RPC_URL_BASE` are correctly defined in your `.env` file.*

### Manual Verification

If the automatic verification fails, you can run the verification command manually.

**For Mantle Sepolia:**

```bash
# Set your ETHERSCAN_API_KEY to your Mantlescan API Key first
export ETHERSCAN_API_KEY=<YOUR_MANTLESCAN_API_KEY>

forge verify-contract \
  --chain mantle-sepolia \
  <TOKEN_ADDRESS> \
  src/token/MockToken.sol:MockToken \
  --watch
```

**For Base Sepolia:**

```bash
# Set your ETHERSCAN_API_KEY to your Basescan API Key first
export ETHERSCAN_API_KEY=<YOUR_BASESCAN_API_KEY>

forge verify-contract \
  --chain base-sepolia \
  <TOKEN_ADDRESS> \
  src/token/MockToken.sol:MockToken \
  --watch
```

## Deterministic Deployment (Same Address on Multiple Chains)

The deployment script now uses `CREATE2` with a fixed salt (`TilepMony_MockTokens_v1`). This allows you to deploy the **same token address** on multiple chains (e.g., Mantle Sepolia and Base Sepolia), provided that:

1. You use the **same deployer wallet** (same Private Key).
2. The `MockToken` contract code and constructor arguments remain exactly the same.
3. The network supports the standard Deterministic Deployment Proxy (most EVM chains do).

**Why is this useful?**
It simplifies configuration. You can use the same `mIDRX` address in your config for both source and destination chains.

## Post-Deployment

After deployment, you will see the addresses of the deployed tokens in the console output. Update your `.env` file in the `bridge-test` directory with these addresses:

```env
MIDRX_ADDRESS=0x...
MUSDT_ADDRESS=0x...
MUSDC_ADDRESS=0x...
```

## Running Bridge Tests

The `bridge-test/test-bridge.js` script has been enhanced to support these tokens. You can specify which token to test by passing its symbol as an argument.

### Usage

```bash
cd bridge-test
node test-bridge.js [TOKEN_SYMBOL]
```

### Examples

Test with mIDRX:

```bash
node test-bridge.js mIDRX
```

Test with mUSDT:

```bash
node test-bridge.js mUSDT
```

Test with mUSDC:

```bash
node test-bridge.js mUSDC
```

If no argument is provided, it will default to `mIDRX` (or whatever is configured as default).
