# Orbitas Subgraph

Read projection for Orbitas passport, obligation `T=(R,Q,S)`, locks and settlement events.

The Subgraph is not canonical settlement state.

## Build

1. Replace `${...}` manifest placeholders with deployment-specific values (or template into `subgraph.generated.yaml`).
2. Generate ABIs from deployed/compiled contracts; event-only placeholders in `abis/` must match source exactly.
3. `npm ci && npm run codegen && npm run build`.

Deployment block for every contract must be recorded by deployment automation.
