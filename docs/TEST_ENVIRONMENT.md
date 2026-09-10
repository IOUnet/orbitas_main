# Orbitas Local / Codex Test Environment

## Goal

Provide one reproducible sandbox for protocol, indexer and MCP development:

```text
Anvil
  ↓
Orbitas contracts
  ↓ events
Graph Node + PostgreSQL + IPFS
  ↓ GraphQL
Orbitas MCP server
  ↓
AI agents / Codex
```

The environment is intentionally local and disposable. It does not represent a production chain, production identity, KYB, custody or legal settlement environment.

## Prerequisites

Required host tools:

- Docker Engine + Docker Compose plugin
- Foundry (`forge`, `cast`)
- Node.js/npm
- `curl`
- `jq`
- `envsubst` (`gettext-base`)

For Codex, run:

```bash
bash .codex/setup.sh
```

The setup script checks the environment, installs Foundry when missing, installs pinned Solidity dependencies and installs indexer/MCP Node dependencies.

## One-command sandbox

```bash
make test-env
```

This target resets the prior local sandbox and then performs:

1. start Anvil, PostgreSQL, IPFS and Graph Node;
2. deploy `ParticipantPassport`;
3. deploy `MultidimensionalObligation`;
4. deploy `BilateralExchange`;
5. deploy `MultilateralClearing`;
6. grant settlement roles;
7. create three deterministic local-only participant passports;
8. seed four BRL obligations, including an open path `A → B → C`;
9. regenerate Subgraph ABIs from Foundry artifacts;
10. render a local Subgraph manifest with the actual deployed addresses;
11. run Graph codegen/build and deploy the Subgraph to local Graph Node;
12. verify participants and obligations are indexed;
13. verify the indexed open path exists;
14. start the MCP HTTP server;
15. verify the MCP transport is reachable.

Expected endpoints:

```text
Anvil JSON-RPC   http://127.0.0.1:8545
GraphQL          http://127.0.0.1:8000/subgraphs/name/orbitas/local
Graph admin      http://127.0.0.1:8020
Graph status     http://127.0.0.1:8030/graphql
IPFS API         http://127.0.0.1:5001
IPFS gateway     http://127.0.0.1:8080
Orbitas MCP      http://127.0.0.1:3000/mcp
```

## Seed topology

A fresh run creates:

```text
Passport 1: Alice Manufacturing
Passport 2: Bob Components
Passport 3: Carol Logistics

Alice → Bob    BRL 100.00
Bob   → Carol  BRL  80.00
Bob   → Alice  BRL  40.00
Carol → Alice  BRL  25.00
```

The first two obligations create the required non-cycle path:

```text
Alice → Bob → Carol
```

The path permits a candidate redirect of up to BRL 80.00 before policy/consent/canonical revalidation.

## Commands

```bash
make test-env          # reset + build complete sandbox
make test-env-up       # infrastructure only
make deploy-local      # deploy protocol contracts
make seed-local        # seed passports/obligations
make deploy-subgraph   # codegen/build/deploy local Subgraph
make smoke             # chain + index + path + MCP smoke checks
make test-contracts    # Foundry tests/invariants
make test-mcp          # MCP TypeScript build
make logs              # follow Docker logs
make test-env-down     # stop services, keep volumes
make test-env-reset    # stop and remove local volumes/state
```

## Local-only keys

The scripts use the default Anvil administrator account and three deterministic test keys. These keys are deliberately committed as local test fixtures.

They MUST NOT be funded or used on any public/test production network.

## Generated state

The following are generated and gitignored:

```text
.test-env/
broadcast/
out/
lib/
indexer/subgraph.local.yaml
indexer/generated/
indexer/build/
```

`.test-env/contracts.env` contains the current local contract addresses.

## Canonical state reminder

The sandbox preserves Orbitas production semantics:

- Anvil contract state is canonical for passport/obligation/lock/settlement state;
- Graph Node is a read projection only;
- the MCP server reads the projection and cannot authorize settlement;
- before real settlement a candidate must be revalidated against the contracts and participant consent policy.

## Troubleshooting

### Graph Node cannot connect to Anvil

```bash
make logs
```

Verify the Compose network contains both services and Graph Node uses:

```text
ethereum: orbitas:http://anvil:8545
```

### Subgraph build fails after a contract change

Regenerate ABI and manifest:

```bash
bash scripts/test-env/render-subgraph.sh
cd indexer
npx graph codegen subgraph.local.yaml
npx graph build subgraph.local.yaml
```

Contract events and Subgraph handler signatures must remain synchronized.

### Old chain state causes duplicate-passport/source errors

Use:

```bash
make test-env-reset
make test-env
```

### MCP starts but queries fail

Confirm the Subgraph is deployed and queryable first:

```bash
curl -sS -X POST \
  http://127.0.0.1:8000/subgraphs/name/orbitas/local \
  -H 'content-type: application/json' \
  --data '{"query":"{ _meta { block { number } hasIndexingErrors } }"}'
```

## CI

`.github/workflows/test-environment.yml` runs the same sandbox path on GitHub Actions. This is intended to prevent local/Codex setup from drifting away from CI behavior.
