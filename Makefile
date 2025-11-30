.PHONY: build run dry-run size

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

run:
	@clear
	@echo "$(CYAN)🚚 [DEPLOY] Deploying smart contract...$(RESET)"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(API_KEY) \
		&& forge script script/Swap.s.sol \
		--rpc-url $(RPC_URL) \
		--broadcast -vvv \
		--verify \
		--etherscan-api-key $(API_KEY)

dry-run:
	@clear
	@echo "Dry running with ${RPC_URL}"
	@forge script script/Token.s.sol \
		--rpc-url $(RPC_URL) -vvv \
		&& forge script script/Swap.s.sol \
		--rpc-url $(RPC_URL) -vvv

size:
	@clear
	@forge build --sizes
