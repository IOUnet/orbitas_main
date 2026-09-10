#!/usr/bin/env bash
set -euo pipefail

: "${ORBITAS_ARCHIVE:?ORBITAS_ARCHIVE is required}"
: "${ORBITAS_REMOTE_PATH:=orbitas_main}"
: "${ORBITAS_DEPLOY_SHA:?ORBITAS_DEPLOY_SHA is required}"

case "$ORBITAS_REMOTE_PATH" in
  /*|*..*|*[!A-Za-z0-9._/-]*)
    echo "ORBITAS_REMOTE_PATH must be a safe path relative to the remote user's home" >&2
    exit 2
    ;;
esac

DEPLOY_ROOT="$HOME/$ORBITAS_REMOTE_PATH"
STAGE_ROOT="${DEPLOY_ROOT}.next"
PREVIOUS_ROOT="${DEPLOY_ROOT}.previous"
FAILED_ROOT="${DEPLOY_ROOT}.failed-${ORBITAS_DEPLOY_SHA:0:12}"

for cmd in tar docker curl jq npm make; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command on remote host: $cmd" >&2
    exit 2
  }
done

docker compose version >/dev/null 2>&1 || {
  echo "Docker Compose plugin is required on the remote host" >&2
  exit 2
}

rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_ROOT"
tar -xzf "$ORBITAS_ARCHIVE" -C "$STAGE_ROOT"

cd "$STAGE_ROOT"

# Install project-local development dependencies and Foundry when necessary.
bash .codex/setup.sh

# Validate the staged revision before interrupting the currently running sandbox.
make test-contracts
make test-mcp

if [[ -d "$DEPLOY_ROOT" ]]; then
  if [[ -x "$DEPLOY_ROOT/scripts/test-env/down.sh" ]]; then
    (
      cd "$DEPLOY_ROOT"
      bash scripts/test-env/down.sh -v || true
    )
  fi
  rm -rf "$PREVIOUS_ROOT"
  mv "$DEPLOY_ROOT" "$PREVIOUS_ROOT"
fi

mv "$STAGE_ROOT" "$DEPLOY_ROOT"
cd "$DEPLOY_ROOT"

set +e
ORBITAS_BIND_HOST=127.0.0.1 make test-env
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "New deployment failed. Preserving failed tree and attempting rollback." >&2
  bash scripts/test-env/down.sh -v || true
  rm -rf "$FAILED_ROOT"
  mv "$DEPLOY_ROOT" "$FAILED_ROOT"

  if [[ -d "$PREVIOUS_ROOT" ]]; then
    mv "$PREVIOUS_ROOT" "$DEPLOY_ROOT"
    cd "$DEPLOY_ROOT"
    ORBITAS_BIND_HOST=127.0.0.1 make test-env || true
  fi

  exit "$status"
fi

mkdir -p .test-env
cat > .test-env/external-deployment.env <<EOF
ORBITAS_DEPLOY_SHA=$ORBITAS_DEPLOY_SHA
ORBITAS_DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ORBITAS_REMOTE_PATH=$ORBITAS_REMOTE_PATH
ORBITAS_BIND_HOST=127.0.0.1
EOF

rm -f "$ORBITAS_ARCHIVE"

cat <<EOF
Orbitas external sandbox deployment complete.
Revision: $ORBITAS_DEPLOY_SHA
Path:     $DEPLOY_ROOT
Anvil:    127.0.0.1:8545
GraphQL:  127.0.0.1:8000/subgraphs/name/orbitas/local
MCP:      127.0.0.1:3000/mcp

Ports are intentionally bound to loopback only. Use an SSH tunnel or a configured reverse proxy for remote access.
EOF
