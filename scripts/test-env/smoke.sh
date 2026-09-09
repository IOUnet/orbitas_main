#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need cast
need curl
need jq
need docker

cd "$ROOT_DIR"
load_contracts

for address in "$PASSPORT_ADDRESS" "$OBLIGATION_ADDRESS" "$BILATERAL_ADDRESS" "$MULTILATERAL_ADDRESS"; do
  code="$(cast code "$address" --rpc-url "$RPC_URL")"
  if [[ -z "$code" || "$code" == "0x" ]]; then
    echo "missing deployed bytecode at $address" >&2
    exit 1
  fi
done
echo "contract bytecode smoke: ok"

query='{"query":"{ participants(first: 10, orderBy: id) { id controller status } obligations(first: 20, orderBy: id) { id issuerPassportId beneficiaryPassportId availableQuantity resourceType currencyCode status } _meta { block { number } hasIndexingErrors } }"}'
response="$(curl -fsS -X POST "$GRAPHQL_ENDPOINT" -H 'content-type: application/json' --data "$query")"

echo "$response" | jq .
participants="$(echo "$response" | jq '.data.participants | length')"
obligations="$(echo "$response" | jq '.data.obligations | length')"
index_errors="$(echo "$response" | jq -r '.data._meta.hasIndexingErrors')"

if (( participants < 3 )); then
  echo "expected at least 3 indexed participants, got $participants" >&2
  exit 1
fi
if (( obligations < 4 )); then
  echo "expected at least 4 indexed obligations, got $obligations" >&2
  exit 1
fi
if [[ "$index_errors" != "false" ]]; then
  echo "subgraph reports indexing errors" >&2
  exit 1
fi

# Verify the seeded open path A(1) -> B(2) -> C(3).
incoming="$(echo "$response" | jq '[.data.obligations[] | select(.issuerPassportId == "1" and .beneficiaryPassportId == "2" and .status == 1)] | length')"
outgoing="$(echo "$response" | jq '[.data.obligations[] | select(.issuerPassportId == "2" and .beneficiaryPassportId == "3" and .status == 1)] | length')"
if (( incoming < 1 || outgoing < 1 )); then
  echo "seeded A->B->C path not present in index" >&2
  exit 1
fi
echo "indexed A->B->C path smoke: ok"

docker compose -f docker-compose.test.yml up -d mcp
for ((i=1; i<=90; i++)); do
  http_code="$(curl -sS -o /dev/null -w '%{http_code}' "$MCP_URL" 2>/dev/null || true)"
  if [[ -n "$http_code" && "$http_code" != "000" ]]; then
    echo "MCP HTTP transport reachable at $MCP_URL (HTTP $http_code)"
    echo "TEST ENVIRONMENT: PASS"
    exit 0
  fi
  sleep 2
done

echo "MCP service did not become reachable" >&2
docker compose -f docker-compose.test.yml logs mcp >&2 || true
exit 1
