# Codex task bootstrap

For a fresh Codex workspace on this repository:

```bash
bash .codex/setup.sh
make test-env
```

Do not start implementation work until `make test-env` either passes or its failure is recorded with service logs.

A passing sandbox provides:

- Anvil at `http://127.0.0.1:8545`
- local Orbitas contracts with seeded participant passports and obligations
- GraphQL at `http://127.0.0.1:8000/subgraphs/name/orbitas/local`
- MCP at `http://127.0.0.1:3000/mcp`

Use `make smoke` after changes that touch contracts, event ABIs, Subgraph mappings, GraphQL queries or MCP tools.

Use `make test-contracts` after every Solidity change.

The sandbox is disposable; if source/token/passport duplicates appear, run:

```bash
make test-env-reset
make test-env
```

Read root `AGENTS.md` before modifying product/protocol behavior.
