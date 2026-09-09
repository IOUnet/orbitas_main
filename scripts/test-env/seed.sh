#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need forge
need cast

cd "$ROOT_DIR"
wait_rpc
load_contracts

fund_key() {
  local pk="$1"
  local addr
  addr="$(cast wallet address --private-key "$pk")"
  cast rpc anvil_setBalance "$addr" 0x21e19e0c9bab2400000 --rpc-url "$RPC_URL" >/dev/null
  echo "$addr"
}

ALICE_ADDRESS="$(fund_key "$ALICE_PK")"
BOB_ADDRESS="$(fund_key "$BOB_PK")"
CAROL_ADDRESS="$(fund_key "$CAROL_PK")"

export PASSPORT_ADDRESS OBLIGATION_ADDRESS ALICE_PK BOB_PK CAROL_PK
forge script script/LocalSeed.s.sol:LocalSeed \
  --rpc-url "$RPC_URL" \
  --broadcast

cat > "$SEED_ENV" <<EOF
ALICE_ADDRESS=$ALICE_ADDRESS
BOB_ADDRESS=$BOB_ADDRESS
CAROL_ADDRESS=$CAROL_ADDRESS
ALICE_PASSPORT_ID=1
BOB_PASSPORT_ID=2
CAROL_PASSPORT_ID=3
EOF

cat "$SEED_ENV"
