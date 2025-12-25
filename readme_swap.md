# Swap System (Foundry) - Base / Mantle Sepolia

This repo includes a mock swap stack (routers + adapters + aggregator) that works with HypERC20 tokens. The scripts deploy the swap stack and set initial rates so you can run swaps or integrate with the workflow executor.

---

## What you get
- `src/swap/SwapAggregator.sol` - Aggregates swaps and whitelists adapters.
- `src/swap/adapters/*Adapter.sol` - Adapters for each router (FusionX, MerchantMoe, Vertex).
- `src/swap/routers/*Router.sol` - Mock routers with fixed exchange rates.
- `script/Swap.s.sol` - Deploy routers + adapters + aggregator, and set default rates.
- `script/UpdateRates.s.sol` - Updates exchange rates (edit hardcoded addresses first).
- `script/AddLiquidity.s.sol` - Funds routers with mock liquidity (edit hardcoded addresses first).
- `test/unit/swap/*` - Unit tests for swap stack.

---

## Prerequisites
- Foundry (`forge`, `cast`, `anvil`) >= nightly 2023-10-01.
- RPC URLs for Base Sepolia and Mantle Sepolia.
- Funded deployer EOA (same `PRIVATE_KEY` on both chains if you want consistent ownership).
- HypERC20 tokens already deployed on Base/Mantle (see `readme_token.md`).

---

## Install dependencies
```bash
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install hyperlane-xyz/hyperlane-monorepo --no-commit
forge remappings > remappings.txt
```

---

## Configure env (`.env.swap`)
Create the swap env file:
```bash
cp .env.example .env.swap
```

Then edit `.env.swap` with your keys, RPCs, and token addresses.
Set `SWAP_SALT_STRING` to a fixed value and keep it the same on every chain so all swap contracts deploy to identical addresses.

Load the swap env file before every Forge command:
```bash
set -a && source .env.swap && forge test -vvv
# or
dotenv -f .env.swap forge script ...
```
Makefile will also load `.env.swap` automatically if present.

---

## Deploy swap stack
`script/Swap.s.sol` deploys:
1) Routers (FusionX, MerchantMoe, Vertex)
2) Adapters
3) Aggregator
4) Initial rates

Deployments use the EIP-2470 singleton factory with `SWAP_SALT_STRING` to keep addresses identical across chains.

### Base Sepolia
Recommended:
```bash
make swap-deploy-base
```

Manual:
```bash
export IDRX_ADDRESS=$BASE_IDRX_ADDRESS
export USDC_ADDRESS=$BASE_USDC_ADDRESS
export USDT_ADDRESS=$BASE_USDT_ADDRESS

forge script script/Swap.s.sol:SwapScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --via-ir \
  -vvv
```

### Mantle Sepolia
Recommended:
```bash
make swap-deploy-mantle
```

Manual:
```bash
export IDRX_ADDRESS=$MANTLE_IDRX_ADDRESS
export USDC_ADDRESS=$MANTLE_USDC_ADDRESS
export USDT_ADDRESS=$MANTLE_USDT_ADDRESS

forge script script/Swap.s.sol:SwapScript \
  --rpc-url $MANTLE_SEPOLIA_RPC_URL \
  --broadcast --via-ir \
  -vvv
```

After each deployment, record the printed addresses in `.env.swap`:
```env
FUSIONX_ROUTER_BASE=0x...
MERCHANT_MOE_ROUTER_BASE=0x...
VERTEX_ROUTER_BASE=0x...
FUSIONX_ADAPTER_BASE=0x...
MERCHANT_MOE_ADAPTER_BASE=0x...
VERTEX_ADAPTER_BASE=0x...
SWAP_AGGREGATOR_BASE=0x...
```

---

## Update rates (optional)
`script/UpdateRates.s.sol` uses hardcoded addresses. Update the constants in the script first, then run:

```bash
make swap-update-rates-base
```

Manual:
```bash
forge script script/UpdateRates.s.sol:UpdateRates \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvv
```

Repeat for Mantle (after updating constants):
```bash
make swap-update-rates-mantle
```

Manual:
```bash
forge script script/UpdateRates.s.sol:UpdateRates \
  --rpc-url $MANTLE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvv
```

---

## Add router liquidity (optional)
`script/AddLiquidity.s.sol` also uses hardcoded adapter + token addresses. Update the constants in the script first, then run:

```bash
forge script script/AddLiquidity.s.sol:AddLiquidity \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvv
```

Repeat for Mantle (after updating constants):
```bash
forge script script/AddLiquidity.s.sol:AddLiquidity \
  --rpc-url $MANTLE_SEPOLIA_RPC_URL \
  --broadcast \
  -vvv
```

---

## Run tests
```bash
# swap-only unit tests
forge test --match-path test/unit/swap/* -vvv

# full suite
forge test -vvv
```

---

## Troubleshooting
- **Swap fails with no liquidity**: fund routers using `script/AddLiquidity.s.sol`.
- **Rates are not updated**: update constants in `script/UpdateRates.s.sol` to your deployed router addresses.
- **Wrong token addresses**: ensure `IDRX_ADDRESS`, `USDC_ADDRESS`, `USDT_ADDRESS` match the chain you are deploying to.
- **Forge ignores `.env.swap`**: prefix commands with `dotenv -f .env.swap` or `source .env.swap`.
