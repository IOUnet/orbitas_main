#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

need docker
cd "$ROOT_DIR"
docker compose -f docker-compose.test.yml down --remove-orphans "$@"
