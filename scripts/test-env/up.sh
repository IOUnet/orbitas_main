#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need docker
need curl

cd "$ROOT_DIR"
docker compose -f docker-compose.test.yml up -d anvil postgres ipfs graph-node

echo "waiting for local infrastructure..."
for ((i=1; i<=60; i++)); do
  if curl -fsS -X POST "$RPC_URL" -H 'content-type: application/json' \
      --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' >/dev/null 2>&1; then
    echo "anvil is ready"
    break
  fi
  if (( i == 60 )); then
    echo "timed out waiting for anvil" >&2
    exit 1
  fi
  sleep 1
done

for ((i=1; i<=60; i++)); do
  if curl -fsS -X POST http://127.0.0.1:5001/api/v0/version >/dev/null 2>&1; then
    echo "ipfs is ready"
    break
  fi
  if (( i == 60 )); then
    echo "timed out waiting for ipfs" >&2
    docker compose -f docker-compose.test.yml logs ipfs >&2 || true
    exit 1
  fi
  sleep 1
done

# Graph Node root endpoints may return non-2xx; use the indexing status GraphQL endpoint.
for ((i=1; i<=60; i++)); do
  if curl -fsS -X POST http://127.0.0.1:8030/graphql \
      -H 'content-type: application/json' \
      --data '{"query":"{ indexingStatuses { subgraph } }"}' >/dev/null 2>&1; then
    echo "graph-node is ready"
    exit 0
  fi
  sleep 2
done

echo "timed out waiting for graph-node" >&2
docker compose -f docker-compose.test.yml logs graph-node >&2 || true
exit 1
