.PHONY: build size rpc run deploy deploy-token deploy-yield deploy-swap deploy-controller \
	inject-liquidity add-liquidity-router update-rates check-router-liquidity \
	swap-deploy-base swap-deploy-mantle swap-deploy-all swap-update-rates-base swap-update-rates-mantle

GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
RESET := \033[0m

ENV_FOUND :=
ifneq (,$(wildcard ./.env.swap))
  include .env.swap
  export $(shell sed 's/=.*//' .env.swap)
  ENV_FOUND := yes
endif
ifneq (,$(wildcard ./.env))
  include .env
  export $(shell sed 's/=.*//' .env)
  ENV_FOUND := yes
endif
ifeq ($(ENV_FOUND),)
  $(error .env or .env.swap file not found! Please create one.)
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
	@forge script script/UpdateRates.s.sol:UpdateRates \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--broadcast -vvv

swap-update-rates-mantle:
	@echo "$(CYAN)[SWAP] Update rates (Mantle Sepolia)...$(RESET)"
	@forge script script/UpdateRates.s.sol:UpdateRates \
		--rpc-url $(MANTLE_SEPOLIA_RPC_URL) \
		--broadcast -vvv
