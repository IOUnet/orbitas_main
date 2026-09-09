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

# Only require Graph Node's admin HTTP listener here. A deployed Subgraph does not exist yet,
# so querying indexingStatuses before `graph create/deploy` is an unnecessarily strict readiness gate.
for ((i=1; i<=60; i++)); do
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8020/ 2>/dev/null || true)"
  if [[ -n "$http_code" && "$http_code" != "000" ]]; then
    echo "graph-node admin listener is ready (HTTP $http_code)"
    exit 0
  fi
  sleep 1
done

echo "timed out waiting for graph-node admin listener" >&2
docker compose -f docker-compose.test.yml logs graph-node >&2 || true
exit 1
