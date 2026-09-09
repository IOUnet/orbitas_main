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

## Bootstrap

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
npm ci
npm run codegen
npm run build
```

MCP:

```bash
cd indexer/mcp
npm ci
npm run build
GRAPHQL_ENDPOINT=https://... npm run start:stdio
```

Read `AGENTS.md` before development. Product docs are under `docs/`. Development skills are under `skills/`.

## Validation status

The repository is a development bootstrap, not an audited deployment. The current execution environment could not install Foundry/npm dependencies, so compile, Foundry tests, Graph codegen/build, and MCP TypeScript build must run in CI or a network-enabled development environment before deployment. See `docs/DEVELOPMENT_STATUS.md`.
