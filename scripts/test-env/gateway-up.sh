#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need docker
need curl

cd "$ROOT_DIR"
load_contracts

docker compose -f docker-compose.test.yml --env-file "$CONTRACTS_ENV" up -d odoo-fixture one-c-fixture gateway

wait_http "http://127.0.0.1:4101/health" "Odoo fixture webhook" 90
wait_http "http://127.0.0.1:4102/health" "1C fixture webhook" 90
wait_http "$GATEWAY_URL/health" "Orbitas Gateway" 120

echo "Gateway and ERP fixture sinks are ready."
