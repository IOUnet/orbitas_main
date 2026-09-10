#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need npm
need curl

cd "$ROOT_DIR"

bash scripts/test-env/render-subgraph.sh

SUBGRAPH_VERSION_LABEL="${SUBGRAPH_VERSION_LABEL:-local-$(date -u +%Y%m%d%H%M%S)}"

echo "deploying orbitas/local subgraph version: $SUBGRAPH_VERSION_LABEL"

pushd indexer >/dev/null
npm install --no-audit --no-fund
npx graph codegen subgraph.local.yaml
npx graph build subgraph.local.yaml
npx graph create --node "$GRAPH_NODE_ADMIN" orbitas/local >/dev/null 2>&1 || true
npx graph deploy \
  --node "$GRAPH_NODE_ADMIN" \
  --ipfs "$IPFS_API" \
  --version-label "$SUBGRAPH_VERSION_LABEL" \
  orbitas/local \
  subgraph.local.yaml
popd >/dev/null

for ((i=1; i<=90; i++)); do
  body="$(curl -fsS -X POST "$GRAPHQL_ENDPOINT" -H 'content-type: application/json' --data '{"query":"{ _meta { block { number } hasIndexingErrors } }"}' 2>/dev/null || true)"
  if [[ "$body" == *'"_meta"'* && "$body" != *'"_meta":null'* ]]; then
    echo "subgraph is queryable"
    echo "$body"
    exit 0
  fi
  sleep 2
done

echo "timed out waiting for local subgraph" >&2
exit 1
