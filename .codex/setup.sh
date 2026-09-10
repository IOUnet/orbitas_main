#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

missing=()
for cmd in docker curl jq npm; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if ! docker compose version >/dev/null 2>&1; then
  missing+=("docker-compose-plugin")
fi

if (( ${#missing[@]} > 0 )); then
  echo "Codex environment is missing required tools: ${missing[*]}" >&2
  echo "Use a Codex image/environment with Docker, Node.js, curl and jq enabled." >&2
  exit 2
fi

if ! command -v envsubst >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y gettext-base
  else
    echo "envsubst is required (package: gettext-base)" >&2
    exit 2
  fi
fi

if ! command -v forge >/dev/null 2>&1; then
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  "$HOME/.foundry/bin/foundryup"
fi

if [[ ! -d lib/openzeppelin-contracts ]]; then
  forge install OpenZeppelin/openzeppelin-contracts@v5.6.1 --no-git
fi
if [[ ! -d lib/forge-std ]]; then
  forge install foundry-rs/forge-std@v1.16.1 --no-git
fi

(cd indexer && npm install --no-audit --no-fund)
(cd indexer/mcp && npm install --no-audit --no-fund)

cat <<'EOF'
Codex setup complete.
Run:
  make test-env
Then use:
  make smoke
  make test-contracts
  make test-mcp
  make logs
EOF
