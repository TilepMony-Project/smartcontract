.PHONY: build size rpc run deploy deploy-token deploy-yield deploy-swap deploy-controller check-router-liquidity

GREEN := \033[0;32m
CYAN := \033[0;36m
YELLOW := \033[1;33m
RED := \033[0;31m
RESET := \033[0m

ifeq (,$(wildcard ./.env))
  $(error .env file not found! Please create one.)
else
  include .env
  export $(shell sed 's/=.*//' .env)
endif

build:
	@clear
	@echo "$(CYAN)🔧 [BUILD] Compiling smart contract...$(RESET)"
	@forge build

size:
	@clear
	@echo "$(GREEN)📄 [REPORT] Generate size report...$(RESET)"
	@forge build --sizes

rpc:
	@clear
	@echo "$(GREEN)🛜 [REPORT] RPC url: ${RPC_URL}$(RESET)"

run:
	@clear
	@echo "$(YELLOW)🧷 [RUN] Start dry running...$(RESET)"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) -vvv \
		&& forge script script/Swap.s.sol \
		--rpc-url $(RPC_URL) -vvv

deploy-token:
	@echo "$(CYAN)🚚 [DEPLOY] Deploying yield tokens...$(RESET)"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-yield:
	@echo "$(CYAN)🚚 [DEPLOY] Deploying yield system...$(RESET)"
	@forge script script/Yield.s.sol:YieldScript \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-swap:
	@echo "$(CYAN)🚚 [DEPLOY] Deploying swap contract...$(RESET)"
	@forge script script/Swap.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

inject-liquidity:
	@echo "$(CYAN)💉 [INJECT] Injecting initial liquidity...$(RESET)"
	@forge script script/YieldLiquidityInjector.s.sol:YieldLiquidityInjector \
		--rpc-url $(RPC_URL) \
		--broadcast -vvvv \
		--legacy


add-liquidity-router:
	@echo "$(CYAN)💧 [LIQUIDITY] Adding liquidity to routers...$(RESET)"
	@forge script script/AddLiquidity.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv

update-rates:
	@echo "$(CYAN)🔄 [UPDATE] Updating exchange rates for mTokens...$(RESET)"
	@forge script script/UpdateRates.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv

check-router-liquidity:
	@echo "$(CYAN)🔍 [CHECK] Checking router liquidity...$(RESET)"
	@forge script script/CheckRouterBalance.s.sol \
		--rpc-url $(RPC_URL) \
		-vvv

deploy-controller:
	@echo "$(CYAN)🚚 [DEPLOY] Deploying Main Controller...$(RESET)"
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
