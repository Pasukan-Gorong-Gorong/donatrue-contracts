-include .env

.PHONY: help deploy-factory deploy-creator

help:
	@echo "Available targets:"
	@echo "  deploy-factory           - Deploy CreatorFactory contract"
	@echo "  deploy-creator           - Deploy Creator contract"
	@echo ""
	@echo "Required environment variables in .env file:"
	@echo "  RPC_URL                  - RPC URL for the target network"
	@echo "  PRIVATE_KEY              - Private key for deployment"
	@echo "  FACTORY_ADDRESS          - Factory contract address (for creator deployment)"
	@echo "  CREATOR_NAME             - Name of the creator (for creator deployment)"
	@echo ""
	@echo "Optional environment variables:"
	@echo "  FEE_PER_DONATION         - Fee per donation in wei (default: 0.01 ether)"
	@echo "  BIO                      - Bio of the creator"
	@echo "  AVATAR                   - Avatar URL of the creator"
	@echo "  LINK_URLS                - Comma-separated list of link URLs"
	@echo "  LINK_LABELS              - Comma-separated list of link labels"

# Deploy CreatorFactory
deploy-factory:
	@if [ -z "$(RPC_URL)" ]; then echo "RPC_URL is required"; exit 1; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY is required"; exit 1; fi
	forge script script/DeployCreatorFactory.s.sol:DeployCreatorFactory --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

# Deploy Creator
deploy-creator:
	@if [ -z "$(RPC_URL)" ]; then echo "RPC_URL is required"; exit 1; fi
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "PRIVATE_KEY is required"; exit 1; fi
	@if [ -z "$(FACTORY_ADDRESS)" ]; then echo "FACTORY_ADDRESS is required"; exit 1; fi
	@if [ -z "$(CREATOR_NAME)" ]; then echo "CREATOR_NAME is required"; exit 1; fi
	forge script script/DeployCreator.s.sol:DeployCreator --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv