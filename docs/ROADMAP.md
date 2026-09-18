# Orbitas Development Roadmap

**Updated:** 2026-09-18  
**Scope:** coordinated roadmap for `orbitas_main`, `orbitas-odoo`, and `orbitas-1c`.

## Current system state

### orbitas_main — protocol core

Implemented:
- `ParticipantPassport.sol`;
- `MultidimensionalObligation.sol` with conceptual `T=(R,Q,S)`;
- `BilateralExchange.sol`;
- `MultilateralClearing.sol` for path-enabled `A→B→C` redirect settlement;
- Foundry unit/invariant suite;
- The Graph Subgraph;
- read-only MCP server for AI agents;
- reproducible Anvil → contracts → Graph Node/IPFS/PostgreSQL → Subgraph → MCP sandbox;
- manual-only GitHub Actions workflows;
- manual external-server installer.

Validated previously:
- protocol compilation/tests;
- quantity-conservation invariant;
- Subgraph codegen/build/deploy in local sandbox;
- MCP path-discovery smoke test.

Main gap:
- there is no canonical Orbitas Gateway/API that translates ERP-facing commands/events into protocol/indexer operations.

### orbitas-odoo — Odoo 19 adapter

Implemented:
- Odoo 19 addon;
- company ↔ Participant Passport binding;
- customer invoice/vendor bill normalization;
- durable obligation bindings;
- durable idempotent outbox;
- HMAC/replay-safe webhook;
- candidate proposal UX and explicit approve/reject;
- settlement-instruction UX;
- multi-company access controls;
- Odoo tests for connector behavior;
- static CI checks.

Validated:
- latest Quality workflow on `main` is green.

Not yet validated:
- install/runtime tests against a real Odoo 19 database;
- end-to-end exchange against Orbitas Core;
- partial payment, multicurrency and credit-note integration scenarios;
- production accounting write-back strategy.

Blocking dependency:
- Odoo transport contract is intentionally configurable because the canonical Orbitas Gateway API is not finalized.

### orbitas-1c — 1C:Enterprise adapter

Implemented:
- MVP BSL module foundation;
- reference adapter for «1С:Бухгалтерия предприятия 3.0»;
- normalized obligation DTO;
- durable outbox/retry design;
- HTTP/JSON transport;
- Participant Passport flow;
- candidate-path/consent workflow;
- read-model/workspace design;
- metadata specification for registers, jobs and workspace;
- test matrix.

Not yet validated:
- no compiled/released `.cfe`;
- no real 1C:Enterprise/EDT compile/install test;
- metadata/forms are not yet assembled into a verified extension artifact;
- confirmed-settlement accounting reflection is not implemented against a concrete BP 3.0 release;
- no end-to-end exchange against Orbitas Core.

Blocking dependency:
- 1C API document explicitly remains provisional until the canonical Orbitas Core API is fixed.

## Critical integration gap

The three repositories now cover both ends of the architecture:

```text
Odoo / 1C
   ↓ normalized obligations + consent
[ MISSING: Canonical Orbitas Gateway/API ]
   ↓
Participant Passport / Obligation contracts
   ↓
Indexer / MCP
   ↓
Path discovery / settlement lifecycle
   ↓
Gateway events
   ↓
Odoo / 1C reconciliation
```

The highest-value next milestone is therefore not another connector feature or another smart contract. It is to make this missing integration layer executable and versioned.

## Roadmap

### M0 — Protocol bootstrap — DONE

- passports;
- multidimensional obligations;
- bilateral exchange;
- multilateral path-enabled clearing;
- indexer;
- MCP;
- deterministic local sandbox.

### M1 — ERP connector foundations — DONE / PARTIALLY VALIDATED

Odoo:
- code-complete initial MVP adapter;
- static CI green;
- runtime Odoo validation outstanding.

1C:
- source-module and metadata design foundation complete;
- `.cfe` assembly/runtime validation outstanding.

### M2 — Canonical Orbitas Gateway v1 — NEXT / P0

Deliver a versioned ERP-facing API owned by `orbitas_main`.

Minimum API domains:
1. Participant Passport
   - create/link;
   - get.
2. Obligations
   - idempotent create/publish;
   - get;
   - update residual/source snapshot under explicit lifecycle rules;
   - cancel/close;
   - list incoming/outgoing.
3. Clearing
   - discover candidate paths;
   - retrieve proposal;
   - approve/reject;
   - revalidate before execution.
4. Settlement
   - create/observe settlement instruction;
   - lock/execute/finalize lifecycle;
   - settlement status query.
5. Events/Webhooks
   - proposal upsert;
   - settlement instruction upsert;
   - settlement finalized/reconciliation-required;
   - replay-safe event IDs and signatures.

Required artifacts:
- OpenAPI 3.x schema;
- JSON Schema / generated types for shared DTOs;
- explicit version prefix, e.g. `/v1`;
- idempotency semantics;
- auth model;
- webhook signature/replay model;
- error model;
- mapping from Gateway operations to smart contracts/indexer;
- contract tests that both ERP adapters can consume.

Acceptance:
- Odoo and 1C fixture payloads pass the same Gateway contract tests;
- no connector-specific domain objects leak into Core;
- Gateway never treats indexer state as final settlement authority.

### M3 — Cross-repository E2E — P0

Extend `make test-env` with a Gateway service and connector simulators.

First deterministic scenario:
1. Odoo fixture creates company/passport and obligation A→B.
2. 1C fixture creates company/passport and obligation B→C.
3. Core discovers A→B→C.
4. required participants approve.
5. Core locks and executes redirect settlement instruction.
6. Subgraph indexes final state.
7. Gateway emits settlement event.
8. connector simulators verify idempotent receipt and reconciliation-required state.

Acceptance:
- full run from ERP fixture → on-chain state → index → clearing → webhook returns green with one command;
- retry/replay tests do not duplicate obligations or settlements.

### M4 — Odoo runtime pilot — P1

- run module install/update tests in real Odoo 19;
- bind connector endpoints to Gateway v1;
- add partial-payment, multicurrency and credit-note cases;
- implement one pilot-approved accounting write-back strategy;
- package installable addon release.

### M5 — 1C BP 3.0 compiled pilot — P1

- choose exact platform + BP 3.0 target versions;
- assemble metadata and managed forms;
- build verified `.cfe`;
- bind HTTP layer to Gateway v1;
- implement one pilot-approved confirmed-settlement accounting strategy;
- execute test matrix on a real infobase.

### M6 — Security / testnet hardening — P1

- smart-contract security review;
- longer stateful invariant/fuzz campaigns;
- Gateway threat model;
- webhook/API security tests;
- external EVM testnet deployment;
- persistent staging environment deployed manually;
- monitoring and recovery runbooks.

### M7 — Pilot readiness — P2

- select first jurisdiction and pilot cluster;
- finalize legal/accounting redirect-settlement treatment;
- define fee rate while retaining Successfully Settled Value as charging event;
- freeze pilot ABI/API versions;
- operational support and reconciliation procedures.

## Explicitly deferred

Until the integration path above is stable:
- QuickBooks connector implementation;
- universal RWA/factoring marketplace;
- public DEX/AMM;
- universal credit score;
- active economic staking/slashing;
- advanced ZKP;
- unrelated Resourceconomy verticals.

## Immediate next step

**Build Canonical Orbitas Gateway v1 in `orbitas_main` and make Odoo + 1C contract-compatible with it before adding more connector functionality.**

Recommended implementation sequence:
1. freeze shared DTOs from the overlap of Odoo and 1C adapter contracts;
2. write OpenAPI v1;
3. implement Gateway participant/obligation read-write path against current contracts/indexer;
4. add clearing proposal/consent/settlement endpoints;
5. add signed/replay-safe outbound webhook delivery;
6. add Gateway to `make test-env`;
7. run cross-repo fixture E2E;
8. only then bind real Odoo/1C runtimes.

This milestone turns the current three good but partially disconnected repositories into one executable product path.
