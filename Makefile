-include .env

.PHONY: deploy-factory deploy-creator help

help:
	@echo "Available targets:"
	@echo "  deploy-factory-sepolia   - Deploy CreatorFactory to Sepolia testnet"
	@echo "  deploy-factory-mainnet   - Deploy CreatorFactory to Ethereum mainnet"
	@echo "  deploy-creator           - Deploy a new Creator contract (requires parameters)"
	@echo ""
	@echo "Required environment variables in .env file:"
	@echo "  RPC_URL                  - RPC URL for the target network"
	@echo "  PRIVATE_KEY              - Private key for deployment"
	@echo "  BASE_IMPL_ADDRESS          - Factory contract address (for creator deployment)"
	@echo ""
	@echo "Optional environment variables:"
	@echo "  FEE_PER_DONATION        - Fee per donation in wei (default: 0.01 ether)"
	@echo "  CREATOR_NAME            - Name of the creator"
	@echo "  CREATOR_BIO             - Bio of the creator"
	@echo "  CREATOR_AVATAR          - Avatar URL of the creator"
	@echo "  CREATOR_LINK_URLS       - Comma-separated list of link URLs"
	@echo "  CREATOR_LINK_LABELS     - Comma-separated list of link labels"

# Deploy CreatorFactory to Sepolia
deploy-factory-sepolia:
	@if [ -z "$(RPC_URL)" ]; then echo "RPC_URL is required"; exit 1; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY is required"; exit 1; fi
	forge script script/DeployCreatorFactory.s.sol \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		-vvv

# Deploy CreatorFactory to Mainnet
deploy-factory-mainnet:
	@if [ -z "$(RPC_URL)" ]; then echo "RPC_URL is required"; exit 1; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY is required"; exit 1; fi
	@echo "Deploying to mainnet... Press Ctrl+C to cancel (waiting 5 seconds)"
	@sleep 5
	forge script script/DeployCreatorFactory.s.sol \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		-vvv

# Deploy Creator contract
deploy-creator:
	@if [ -z "$(RPC_URL)" ]; then echo "RPC_URL is required"; exit 1; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY is required"; exit 1; fi
	@if [ -z "$(BASE_IMPL_ADDRESS)" ]; then echo "BASE_IMPL_ADDRESS is required"; exit 1; fi
	@if [ -z "$(CREATOR_NAME)" ]; then echo "CREATOR_NAME is required"; exit 1; fi
	forge script script/DeployCreator.s.sol \
		--rpc-url $(RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--sig "run(string,uint96,address,string,string,string[],string[])" \
		$(CREATOR_NAME) \
		${FEE_PER_DONATION:-10000000000000000} \
		$(BASE_IMPL_ADDRESS) \
		${CREATOR_BIO:-""} \
		${CREATOR_AVATAR:-""} \
		"[${CREATOR_LINK_URLS:-}]" \
		"[${CREATOR_LINK_LABELS:-}]" \
		-vvv
