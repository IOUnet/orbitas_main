# Development Status

**Updated:** 2026-09-18

## Current validated baseline

`orbitas_main` now contains:
- ParticipantPassport contract;
- MultidimensionalObligation contract with `T=(R,Q,S)` protocol hooks;
- BilateralExchange contract;
- MultilateralClearing path contract;
- Foundry unit tests and stateful obligation invariant test;
- The Graph schema/manifest/mappings;
- MCP read-only server over the indexer;
- reproducible local/Codex sandbox;
- manual-only GitHub Actions workflows;
- manual external-server installation path.

The earlier bootstrap blockers in this file are obsolete: the GitHub repository exists, the bootstrap is merged, and the local sandbox has been exercised end-to-end.

## Cross-repository state

### orbitas-odoo

Initial Odoo 19 connector MVP is merged. It includes:
- Participant Passport binding;
- invoice/vendor-bill normalization;
- durable bindings and outbox;
- webhook security/replay protection;
- explicit clearing consent;
- settlement-instruction UI;
- multi-company isolation;
- repository tests/static quality checks.

Latest `main` Quality workflow is green.

Still outstanding:
- full Odoo 19 runtime/install validation;
- binding to canonical Orbitas Gateway v1;
- extended partial-payment/multicurrency/credit-note scenarios;
- production accounting write-back.

### orbitas-1c

Initial 1C:Enterprise MVP foundation is merged for a BP 3.0 reference adapter.

Implemented source/design:
- BSL common modules;
- obligation normalization;
- outbox/retry;
- HTTP/JSON;
- passport flow;
- candidate-path/consent logic;
- workspace/read-model;
- metadata and test specifications.

Still outstanding:
- actual metadata/forms assembled into a compiled `.cfe`;
- real 1C/EDT validation;
- binding to canonical Orbitas Gateway v1;
- production confirmed-settlement accounting reflection.

## Current P0 gap

There is still no canonical ERP-facing Gateway/API in `orbitas_main`.

Both ERP repositories deliberately carry provisional/configurable API contracts. The next development milestone is therefore **Canonical Orbitas Gateway v1 + cross-repository E2E**, not more isolated connector features.

See [ROADMAP.md](ROADMAP.md).

## Deployment policy

Build/test workflows in `orbitas_main` are manual-only. External-server deployment is also manual by command. No automatic deployment is assumed.

## Production readiness

Not production-ready yet.

Before a real pilot:
1. Gateway v1 and cross-repo E2E;
2. real Odoo runtime validation;
3. compiled/tested 1C extension for a pinned BP 3.0/platform version;
4. smart-contract and Gateway security review;
5. selected jurisdiction/accounting strategy;
6. testnet/staging operational runbooks;
7. external review before economically meaningful obligations or collateral are used.
