# Orbitas Main

Orbitas is a P2P clearing network for ERP-backed tokenized business obligations.

## MVP contract stack

1. `ParticipantPassport.sol` — permissionless SELF_DECLARED participant identity.
2. `MultidimensionalObligation.sol` — tokenized obligation with conceptual `T=(R,Q,S)` state, locks and settlement hooks.
3. `BilateralExchange.sol` — atomic two-party reciprocal clearing.
4. `MultilateralClearing.sol` — path-enabled `A→B→C` redirect settlement instructions.

## Indexing / AI access

- `indexer/` — The Graph Subgraph projection.
- `indexer/mcp/` — read-only MCP server for AI agents.

## Codex / local test environment

The complete disposable sandbox can be started with one command:

```bash
bash .codex/setup.sh   # first run in a Codex environment
make test-env
```

It starts and wires:

```text
Anvil
  ↓
Orbitas contracts + seeded A→B→C obligations
  ↓
Graph Node + PostgreSQL + IPFS
  ↓
Orbitas Subgraph
  ↓
MCP HTTP server for AI agents
```

Endpoints after a successful run:

```text
Anvil:   http://127.0.0.1:8545
GraphQL: http://127.0.0.1:8000/subgraphs/name/orbitas/local
MCP:     http://127.0.0.1:3000/mcp
```

Useful commands:

```bash
make smoke
make test-contracts
make test-mcp
make logs
make test-env-reset
```

See `docs/TEST_ENVIRONMENT.md` for architecture and troubleshooting.

## Manual contract bootstrap

Install Foundry, then pin dependencies:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.6.1 --no-git
forge install foundry-rs/forge-std@v1.16.1 --no-git
forge fmt --check
forge build
forge test
```

Subgraph:

```bash
cd indexer
npm install
npm run codegen
npm run build
```

MCP:

```bash
cd indexer/mcp
npm install
npm run build
GRAPHQL_ENDPOINT=https://... npm run start:stdio
```

Read `AGENTS.md` before development. Product docs are under `docs/`. Development skills are under `skills/`.

## Validation status

The bootstrap Solidity stack compiles in GitHub Actions and the current contract suite passes, including stateful quantity-conservation invariants. The repository is still a development bootstrap, not an audited deployment.

The `test-environment` workflow additionally validates the disposable Anvil → contracts → Graph Node/IPFS/PostgreSQL → Subgraph → MCP sandbox used by local development and Codex.
