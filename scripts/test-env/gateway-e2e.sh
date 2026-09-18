#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need curl
need jq
need docker

cd "$ROOT_DIR"
load_contracts
if [[ -f "$SEED_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$SEED_ENV"
fi

post_json() {
  local path="$1"
  local body="$2"
  curl -fsS -X POST "$GATEWAY_URL$path" \
    -H "Authorization: Bearer $ORBITAS_API_TOKEN" \
    -H "content-type: application/json" \
    --data-binary "$body"
}

post_idempotent() {
  local path="$1"
  local key="$2"
  local body="$3"
  curl -fsS -X POST "$GATEWAY_URL$path" \
    -H "Authorization: Bearer $ORBITAS_API_TOKEN" \
    -H "content-type: application/json" \
    -H "Idempotency-Key: $key" \
    --data-binary "$body"
}

sign_digest() {
  local digest="$1"
  local private_key="$2"
  docker compose -f docker-compose.test.yml --env-file "$CONTRACTS_ENV" exec -T gateway \
    node test/sign-digest.mjs "$digest" "$private_key" | tail -n1 | tr -d '\r'
}

echo "registering ERP webhook subscriptions..."
post_idempotent "/v1/webhooks/subscriptions" "e2e:webhook:odoo:v1" \
  '{"id":"e2e-odoo","source_system":"odoo","participant_id":"1","callback_url":"http://odoo-fixture:4101/orbitas/webhook","secret":"odoo-local-secret"}' >/dev/null
post_idempotent "/v1/webhooks/subscriptions" "e2e:webhook:1c:v1" \
  '{"id":"e2e-1c","source_system":"1c-enterprise","participant_id":"2","callback_url":"http://one-c-fixture:4102/orbitas/webhook","secret":"1c-local-secret"}' >/dev/null

echo "linking ERP companies to existing local Participant Passports..."
post_idempotent "/v1/passports/link" "e2e:link:odoo:company-1:v1" \
  '{"passport_id":"1","source":{"system":"odoo","instance_id":"odoo-e2e","company_id":"1"}}' >/dev/null
post_idempotent "/v1/passports/link" "e2e:link:1c:organization-1:v1" \
  '{"passport_id":"2","source":{"system":"1c-enterprise","instance_id":"bp30-e2e","company_id":"organization-1"}}' >/dev/null

echo "publishing Odoo A→B obligation through Gateway..."
odoo_body="$(cat gateway/fixtures/odoo-obligation.json)"
odoo_response="$(post_idempotent "/v1/obligations" "e2e:odoo:account.move:9001:v1" "$odoo_body")"
echo "$odoo_response" | jq .
odoo_obligation_id="$(echo "$odoo_response" | jq -r '.obligation_id')"
[[ "$odoo_obligation_id" =~ ^[0-9]+$ ]]

echo "verifying Odoo publication idempotency..."
odoo_replay="$(post_idempotent "/v1/obligations" "e2e:odoo:account.move:9001:v1" "$odoo_body")"
[[ "$(echo "$odoo_replay" | jq -r '.obligation_id')" == "$odoo_obligation_id" ]]
[[ "$(echo "$odoo_replay" | jq -r '.idempotency_replayed')" == "true" ]]

echo "publishing 1C B→C obligation through Gateway..."
one_c_body="$(cat gateway/fixtures/1c-obligation.json)"
one_c_response="$(post_idempotent "/v1/obligations" "e2e:1c:receipt:9002:v1" "$one_c_body")"
echo "$one_c_response" | jq .
one_c_obligation_id="$(echo "$one_c_response" | jq -r '.obligation_id')"
[[ "$one_c_obligation_id" =~ ^[0-9]+$ ]]

echo "discovering explicit cross-ERP A→B→C path..."
discover_body="$(jq -nc \
  --arg incoming "$odoo_obligation_id" \
  --arg outgoing "$one_c_obligation_id" \
  '{incoming_obligation_id:$incoming,outgoing_obligation_id:$outgoing,expires_in_seconds:900}')"
proposal="$(post_idempotent "/v1/clearing/discover" "e2e:discover:v1" "$discover_body")"
echo "$proposal" | jq .
proposal_id="$(echo "$proposal" | jq -r '.id')"
path_digest="$(echo "$proposal" | jq -r '.path_digest')"
[[ "$(echo "$proposal" | jq -r '.matched_quantity_base_units')" == "8000" ]]

echo "collecting explicit A/B/C consent signatures..."
alice_sig="$(sign_digest "$path_digest" "$ALICE_PK")"
bob_sig="$(sign_digest "$path_digest" "$BOB_PK")"
carol_sig="$(sign_digest "$path_digest" "$CAROL_PK")"

post_json "/v1/proposals/$proposal_id/approve" \
  "$(jq -nc --arg sig "$alice_sig" '{passport_id:"1",signature:$sig}')" >/dev/null
post_json "/v1/proposals/$proposal_id/approve" \
  "$(jq -nc --arg sig "$bob_sig" '{passport_id:"2",signature:$sig}')" >/dev/null
approval_final="$(post_json "/v1/proposals/$proposal_id/approve" \
  "$(jq -nc --arg sig "$carol_sig" '{passport_id:"3",signature:$sig}')")"
[[ "$(echo "$approval_final" | jq -r '.state')" == "APPROVED" ]]

echo "creating on-chain redirect settlement instruction..."
settlement="$(post_idempotent "/v1/proposals/$proposal_id/execute" "e2e:execute:$proposal_id:v1" '{}')"
echo "$settlement" | jq .
settlement_id="$(echo "$settlement" | jq -r '.id')"
[[ "$settlement_id" =~ ^0x[0-9a-fA-F]{64}$ ]]

echo "verifying settlement execution idempotency..."
settlement_replay="$(post_idempotent "/v1/proposals/$proposal_id/execute" "e2e:execute:$proposal_id:v1" '{}')"
[[ "$(echo "$settlement_replay" | jq -r '.id')" == "$settlement_id" ]]
[[ "$(echo "$settlement_replay" | jq -r '.idempotency_replayed')" == "true" ]]

echo "preparing fulfillment confirmation digest..."
confirmation="$(post_json "/v1/settlements/$settlement_id/prepare-confirmation" \
  '{"fulfillment_evidence":{"kind":"e2e","reference":"ERP-REDIRECT-PAID"}}')"
confirmation_digest="$(echo "$confirmation" | jq -r '.confirmation_digest')"
evidence_hash="$(echo "$confirmation" | jq -r '.fulfillment_evidence_hash')"
deadline="$(echo "$confirmation" | jq -r '.deadline')"

bob_confirm_sig="$(sign_digest "$confirmation_digest" "$BOB_PK")"
carol_confirm_sig="$(sign_digest "$confirmation_digest" "$CAROL_PK")"
confirm_body="$(jq -nc \
  --arg evidence "$evidence_hash" \
  --arg deadline "$deadline" \
  --arg intermediary "$bob_confirm_sig" \
  --arg receiver "$carol_confirm_sig" \
  '{fulfillment_evidence_hash:$evidence,deadline:$deadline,intermediary_signature:$intermediary,receiver_signature:$receiver}')"

echo "confirming redirect fulfillment..."
confirmed="$(post_idempotent "/v1/settlements/$settlement_id/confirm" "e2e:confirm:$settlement_id:v1" "$confirm_body")"
echo "$confirmed" | jq .
[[ "$(echo "$confirmed" | jq -r '.state')" == "SETTLED" ]]
[[ "$(echo "$confirmed" | jq -r '.chain_state.status')" == "SETTLED" ]]

echo "verifying settlement confirmation idempotency..."
confirmed_replay="$(post_idempotent "/v1/settlements/$settlement_id/confirm" "e2e:confirm:$settlement_id:v1" "$confirm_body")"
[[ "$(echo "$confirmed_replay" | jq -r '.idempotency_replayed')" == "true" ]]

echo "checking canonical residuals..."
incoming_state="$(curl -fsS "$GATEWAY_URL/v1/obligations/$odoo_obligation_id")"
outgoing_state="$(curl -fsS "$GATEWAY_URL/v1/obligations/$one_c_obligation_id")"
[[ "$(echo "$incoming_state" | jq -r '.available_quantity')" == "2000" ]]
[[ "$(echo "$outgoing_state" | jq -r '.available_quantity')" == "0" ]]

echo "waiting for Subgraph to index Gateway-created settlement..."
indexed=false
graph_response='{}'
for ((i=1; i<=60; i++)); do
  query="{ obligations(where:{id_in:[\"$odoo_obligation_id\",\"$one_c_obligation_id\"]}) { id availableQuantity settledQuantity } settlementInstruction(id:\"$settlement_id\") { id status quantity } _meta { hasIndexingErrors } }"
  graph_response="$(curl -fsS -X POST "$GRAPHQL_ENDPOINT" \
    -H 'content-type: application/json' \
    --data "$(jq -nc --arg q "$query" '{query:$q}')")"
  if [[ "$(echo "$graph_response" | jq -r '.data._meta.hasIndexingErrors // true')" == "false" ]] \
    && [[ "$(echo "$graph_response" | jq '.data.obligations | length')" == "2" ]] \
    && [[ "$(echo "$graph_response" | jq -r '.data.settlementInstruction.status // -1')" == "2" ]]; then
    indexed=true
    break
  fi
  sleep 1
done
if [[ "$indexed" != "true" ]]; then
  echo "Subgraph did not index final Gateway E2E state" >&2
  echo "$graph_response" | jq . >&2
  exit 1
fi

echo "checking signed/replay-safe ERP webhook delivery..."
odoo_events="$(curl -fsS http://127.0.0.1:4101/events)"
one_c_events="$(curl -fsS http://127.0.0.1:4102/events)"
for payload in "$odoo_events" "$one_c_events"; do
  for event_type in clearing.proposal.upsert settlement.instruction.upsert settlement.settled; do
    count="$(echo "$payload" | jq --arg type "$event_type" '[.events[] | select(.type==$type)] | length')"
    if (( count < 1 )); then
      echo "missing webhook event $event_type" >&2
      echo "$payload" | jq . >&2
      exit 1
    fi
  done
  total="$(echo "$payload" | jq '.events | length')"
  unique="$(echo "$payload" | jq '[.events[].id] | unique | length')"
  [[ "$total" == "$unique" ]]
done

echo "CROSS-ERP GATEWAY E2E: PASS"
echo "Odoo obligation: $odoo_obligation_id"
echo "1C obligation:   $one_c_obligation_id"
echo "Proposal:        $proposal_id"
echo "Settlement:      $settlement_id"
