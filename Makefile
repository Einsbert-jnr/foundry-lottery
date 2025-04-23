-include .env

.PHONY: all test deploy

build:; forge build

test:
	forge test

install:
	forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contract@1.1.1 --no-commit && forge install  foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmission11/solmate@v6 --no-commit


deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvv

deploy-anvil:;
