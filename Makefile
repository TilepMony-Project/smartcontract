.PHONY: build size rpc run deploy deploy-token deploy-swap

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
	@echo "$(CYAN)🚚 [DEPLOY] Deploying token contract...$(RESET)"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(API_KEY)

deploy-swap:
	@echo "$(CYAN)🚚 [DEPLOY] Deploying swap contract...$(RESET)"
	@forge script script/Swap.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(API_KEY)

deploy:
	@clear
	@$(MAKE) deploy-token
	@$(MAKE) deploy-swap
