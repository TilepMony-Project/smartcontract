.PHONY: build size rpc run deploy deploy-token deploy-yield deploy-swap deploy-controller \
	inject-liquidity add-liquidity-router update-rates check-router-liquidity \
	swap-deploy-base swap-deploy-mantle swap-deploy-all swap-update-rates-base swap-update-rates-mantle \
	swap-add-liquidity-base swap-add-liquidity-mantle swap-add-liquidity-all

GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
RESET := \033[0m

# Load env based on target prefix (default .env):
# - swap-*     -> .env.swap
# - token-*    -> .env.token
# - bridge-*   -> .env.token
GOAL_PREFIX   := $(firstword $(subst -, ,$(firstword $(MAKECMDGOALS))))
ENV_FILE      := .env

ifeq ($(GOAL_PREFIX),swap)
  ENV_FILE := .env.swap
endif
ifeq ($(GOAL_PREFIX),token)
  ENV_FILE := .env.token
endif
ifeq ($(GOAL_PREFIX),bridge)
  ENV_FILE := .env.token
endif

ifneq (,$(wildcard $(ENV_FILE)))
  include $(ENV_FILE)
  export $(shell sed 's/=.*//' $(ENV_FILE))
else
  $(error Missing $(ENV_FILE) for target $(MAKECMDGOALS))
endif

build:
	@clear
	@echo "$(CYAN)[BUILD] Compiling smart contract...$(RESET)"
	@forge build

size:
	@clear
	@echo "$(GREEN)[REPORT] Generate size report...$(RESET)"
	@forge build --sizes

rpc:
	@clear
	@echo "$(GREEN)[REPORT] RPC url: ${RPC_URL}$(RESET)"

run:
	@clear
	@echo "$(YELLOW)[RUN] Start dry running...$(RESET)"
	@forge script script/Token.s.sol --rpc-url $(RPC_URL) -vvv \
		&& forge script script/Swap.s.sol --rpc-url $(RPC_URL) -vvv

deploy-token:
	@echo "$(CYAN)[DEPLOY] Deploying yield tokens...$(RESET)"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-yield:
	@echo "$(CYAN)[DEPLOY] Deploying yield system...$(RESET)"
	@forge script script/Yield.s.sol:YieldScript \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-swap:
	@echo "$(CYAN)[DEPLOY] Deploying swap contract...$(RESET)"
	@forge script script/Swap.s.sol:SwapScript \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

inject-liquidity:
	@echo "$(CYAN)[INJECT] Injecting initial liquidity...$(RESET)"
	@forge script script/YieldLiquidityInjector.s.sol:YieldLiquidityInjector \
		--rpc-url $(RPC_URL) \
		--broadcast -vvvv \
		--legacy

add-liquidity-router:
	@echo "$(CYAN)[LIQUIDITY] Adding liquidity to routers...$(RESET)"
	@forge script script/AddLiquidity.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv

# Swap liquidity (Base + Mantle)
swap-add-liquidity-base:
	@echo "$(CYAN)[SWAP] Adding liquidity (Base Sepolia)...$(RESET)"
	@SWAP_CHAIN=BASE \
	FUSIONX_ADAPTER=$(FUSIONX_ADAPTER_BASE) \
	MERCHANT_MOE_ADAPTER=$(MERCHANT_MOE_ADAPTER_BASE) \
	VERTEX_ADAPTER=$(VERTEX_ADAPTER_BASE) \
	IDRX_ADDRESS=$(BASE_IDRX_ADDRESS) \
	USDC_ADDRESS=$(BASE_USDC_ADDRESS) \
	USDT_ADDRESS=$(BASE_USDT_ADDRESS) \
	forge script script/AddLiquidity.s.sol:AddLiquidity \
		--rpc-url "$(BASE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

swap-add-liquidity-mantle:
	@echo "$(CYAN)[SWAP] Adding liquidity (Mantle Sepolia)...$(RESET)"
	@SWAP_CHAIN=MANTLE \
	FUSIONX_ADAPTER=$(FUSIONX_ADAPTER_MANTLE) \
	MERCHANT_MOE_ADAPTER=$(MERCHANT_MOE_ADAPTER_MANTLE) \
	VERTEX_ADAPTER=$(VERTEX_ADAPTER_MANTLE) \
	IDRX_ADDRESS=$(MANTLE_IDRX_ADDRESS) \
	USDC_ADDRESS=$(MANTLE_USDC_ADDRESS) \
	USDT_ADDRESS=$(MANTLE_USDT_ADDRESS) \
	forge script script/AddLiquidity.s.sol:AddLiquidity \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

swap-add-liquidity-all:
	@$(MAKE) swap-add-liquidity-base
	@$(MAKE) swap-add-liquidity-mantle

update-rates:
	@echo "$(CYAN)[UPDATE] Updating exchange rates for mTokens...$(RESET)"
	@forge script script/UpdateRates.s.sol:UpdateRates \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv

check-router-liquidity:
	@echo "$(CYAN)[CHECK] Checking router liquidity...$(RESET)"
	@forge script script/CheckRouterBalance.s.sol \
		--rpc-url $(RPC_URL) \
		-vvv

deploy-controller:
	@echo "$(CYAN)[DEPLOY] Deploying Main Controller...$(RESET)"
	@forge script script/MainController.s.sol:MainControllerScript \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy:
	@clear
	@$(MAKE) deploy-token
	@$(MAKE) deploy-yield
	@$(MAKE) deploy-swap
	@$(MAKE) deploy-controller

# === Swap (Base + Mantle) ===
swap-deploy-base:
	@echo "$(CYAN)[SWAP] Deploying swap stack (Base Sepolia)...$(RESET)"
	@RPC_URL="$(BASE_SEPOLIA_RPC_URL)" \
	SWAP_CHAIN=BASE \
	IDRX_ADDRESS="$(BASE_IDRX_ADDRESS)" \
	USDC_ADDRESS="$(BASE_USDC_ADDRESS)" \
	USDT_ADDRESS="$(BASE_USDT_ADDRESS)" \
	forge script script/Swap.s.sol:SwapScript \
		--rpc-url "$(BASE_SEPOLIA_RPC_URL)" \
		--broadcast --via-ir -vvv

swap-deploy-mantle:
	@echo "$(CYAN)[SWAP] Deploying swap stack (Mantle Sepolia)...$(RESET)"
	@RPC_URL="$(MANTLE_SEPOLIA_RPC_URL)" \
	SWAP_CHAIN=MANTLE \
	IDRX_ADDRESS="$(MANTLE_IDRX_ADDRESS)" \
	USDC_ADDRESS="$(MANTLE_USDC_ADDRESS)" \
	USDT_ADDRESS="$(MANTLE_USDT_ADDRESS)" \
	forge script script/Swap.s.sol:SwapScript \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		--gas-estimate-multiplier 300 \
		--broadcast --via-ir -vvv

swap-deploy-all:
	@$(MAKE) swap-deploy-base
	@$(MAKE) swap-deploy-mantle

swap-update-rates-base:
	@echo "$(CYAN)[SWAP] Update rates (Base Sepolia)...$(RESET)"
	@SWAP_CHAIN=BASE \
	forge script script/UpdateRates.s.sol:UpdateRates \
		--rpc-url "$(BASE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

swap-update-rates-mantle:
	@echo "$(CYAN)[SWAP] Update rates (Mantle Sepolia)...$(RESET)"
	@SWAP_CHAIN=MANTLE \
	forge script script/UpdateRates.s.sol:UpdateRates \
		--rpc-url "$(MANTLE_SEPOLIA_RPC_URL)" \
		--broadcast -vvv

swap-update-rates-all:
	@$(MAKE) swap-update-rates-base
	@$(MAKE) swap-update-rates-mantle