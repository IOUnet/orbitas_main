#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/.test-env"
CONTRACTS_ENV="$STATE_DIR/contracts.env"
SEED_ENV="$STATE_DIR/seed.env"
RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
GRAPH_NODE_ADMIN="${GRAPH_NODE_ADMIN:-http://127.0.0.1:8020}"
GRAPHQL_ENDPOINT="${GRAPHQL_ENDPOINT:-http://127.0.0.1:8000/subgraphs/name/orbitas/local}"
IPFS_API="${IPFS_API:-http://127.0.0.1:5001}"
MCP_URL="${MCP_URL:-http://127.0.0.1:3000/mcp}"

# Anvil default account #0. LOCAL TESTING ONLY.
ADMIN_PK="${ADMIN_PK:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
ORBITAS_ADMIN="${ORBITAS_ADMIN:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"

# Deterministic low-value local-only keys for seeded companies.
ALICE_PK="${ALICE_PK:-0x00000000000000000000000000000000000000000000000000000000000a11ce}"
BOB_PK="${BOB_PK:-0x0000000000000000000000000000000000000000000000000000000000000b0b}"
CAROL_PK="${CAROL_PK:-0x000000000000000000000000000000000000000000000000000000000000ca11}"

mkdir -p "$STATE_DIR"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

wait_http() {
  local url="$1"
  local name="$2"
  local attempts="${3:-60}"
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$name is ready"
      return 0
    fi
    sleep 2
  done
  echo "timed out waiting for $name at $url" >&2
  return 1
}

wait_rpc() {
  local attempts="${1:-60}"
  for ((i=1; i<=attempts; i++)); do
    if cast block-number --rpc-url "$RPC_URL" >/dev/null 2>&1; then
      echo "anvil is ready"
      return 0
    fi
    sleep 1
  done
  echo "timed out waiting for anvil at $RPC_URL" >&2
  return 1
}

load_contracts() {
  if [[ ! -f "$CONTRACTS_ENV" ]]; then
    echo "missing $CONTRACTS_ENV; run make deploy-local first" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$CONTRACTS_ENV"
  export PASSPORT_ADDRESS OBLIGATION_ADDRESS BILATERAL_ADDRESS MULTILATERAL_ADDRESS
}
