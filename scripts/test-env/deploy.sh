#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need forge
need cast
need jq

cd "$ROOT_DIR"
wait_rpc

if [[ ! -d lib/openzeppelin-contracts ]]; then
  forge install OpenZeppelin/openzeppelin-contracts@v5.6.1 --no-git
fi
if [[ ! -d lib/forge-std ]]; then
  forge install foundry-rs/forge-std@v1.16.1 --no-git
fi

export ORBITAS_ADMIN
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC_URL" \
  --private-key "$ADMIN_PK" \
  --broadcast

BROADCAST_FILE="$ROOT_DIR/broadcast/Deploy.s.sol/31337/run-latest.json"
if [[ ! -f "$BROADCAST_FILE" ]]; then
  echo "deployment broadcast not found: $BROADCAST_FILE" >&2
  exit 1
fi

address_for() {
  local name="$1"
  jq -r --arg n "$name" '.transactions[] | select(.transactionType == "CREATE" and .contractName == $n) | .contractAddress' "$BROADCAST_FILE" | tail -n1
}

PASSPORT_ADDRESS="$(address_for ParticipantPassport)"
OBLIGATION_ADDRESS="$(address_for MultidimensionalObligation)"
BILATERAL_ADDRESS="$(address_for BilateralExchange)"
MULTILATERAL_ADDRESS="$(address_for MultilateralClearing)"

for v in PASSPORT_ADDRESS OBLIGATION_ADDRESS BILATERAL_ADDRESS MULTILATERAL_ADDRESS; do
  if [[ -z "${!v:-}" || "${!v}" == "null" ]]; then
    echo "could not resolve $v from broadcast" >&2
    exit 1
  fi
done

cat > "$CONTRACTS_ENV" <<EOF
PASSPORT_ADDRESS=$PASSPORT_ADDRESS
OBLIGATION_ADDRESS=$OBLIGATION_ADDRESS
BILATERAL_ADDRESS=$BILATERAL_ADDRESS
MULTILATERAL_ADDRESS=$MULTILATERAL_ADDRESS
DEPLOY_BLOCK=0
EOF

printf 'deployed contracts:\n'
cat "$CONTRACTS_ENV"
