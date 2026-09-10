#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need jq
need envsubst

cd "$ROOT_DIR"
load_contracts

for artifact in ParticipantPassport MultidimensionalObligation BilateralExchange MultilateralClearing; do
  file="out/${artifact}.sol/${artifact}.json"
  if [[ ! -f "$file" ]]; then
    echo "missing Foundry artifact $file; run forge build/deploy first" >&2
    exit 1
  fi
  jq '.abi' "$file" > "indexer/abis/${artifact}.json"
done

export NETWORK=orbitas
export PASSPORT_ADDRESS OBLIGATION_ADDRESS BILATERAL_ADDRESS MULTILATERAL_ADDRESS
export PASSPORT_START_BLOCK=0
export OBLIGATION_START_BLOCK=0
export BILATERAL_START_BLOCK=0
export MULTILATERAL_START_BLOCK=0

envsubst '${NETWORK} ${PASSPORT_ADDRESS} ${OBLIGATION_ADDRESS} ${BILATERAL_ADDRESS} ${MULTILATERAL_ADDRESS} ${PASSPORT_START_BLOCK} ${OBLIGATION_START_BLOCK} ${BILATERAL_START_BLOCK} ${MULTILATERAL_START_BLOCK}' \
  < indexer/subgraph.yaml > indexer/subgraph.local.yaml

echo "rendered indexer/subgraph.local.yaml"
