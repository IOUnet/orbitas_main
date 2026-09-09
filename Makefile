SHELL := /usr/bin/env bash

.PHONY: test-env test-env-up test-env-down test-env-reset deploy-local seed-local deploy-subgraph smoke test-contracts test-indexer test-mcp logs

test-env: test-env-reset test-env-up deploy-local seed-local deploy-subgraph smoke
	@echo "Orbitas local test environment is ready."
	@echo "Anvil:   http://127.0.0.1:8545"
	@echo "GraphQL: http://127.0.0.1:8000/subgraphs/name/orbitas/local"
	@echo "MCP:     http://127.0.0.1:3000/mcp"

test-env-up:
	bash scripts/test-env/up.sh

test-env-down:
	bash scripts/test-env/down.sh

test-env-reset:
	-bash scripts/test-env/down.sh -v
	rm -rf .test-env indexer/subgraph.local.yaml broadcast/Deploy.s.sol/31337 broadcast/LocalSeed.s.sol/31337

deploy-local:
	bash scripts/test-env/deploy.sh

seed-local:
	bash scripts/test-env/seed.sh

deploy-subgraph:
	bash scripts/test-env/deploy-subgraph.sh

smoke:
	bash scripts/test-env/smoke.sh

test-contracts:
	FOUNDRY_PROFILE=ci forge test -vvv

test-indexer:
	cd indexer && npm install --no-audit --no-fund && npm run codegen -- subgraph.local.yaml && npm run build -- subgraph.local.yaml

test-mcp:
	cd indexer/mcp && npm install --no-audit --no-fund && npm run build

logs:
	docker compose -f docker-compose.test.yml logs -f --tail=200
