---
name: orbitas-the-graph-indexer
version: "1.0.0"
description: The Graph/Subgraph and MCP indexer development rules for Orbitas on-chain passport, multidimensional obligation and settlement projections.
license: Internal project guidance; source references retain their own licenses.
---

# Orbitas The Graph / MCP Indexer Skill

Use this skill when designing, implementing, reviewing or querying the Orbitas Subgraph/indexer and its MCP interface.

## 1. Current baseline

At skill creation time:

- `@graphprotocol/graph-cli`: **0.98.1**
- `@graphprotocol/graph-ts`: **0.38.2**
- use current supported Subgraph spec version; repo baseline uses `specVersion: 1.3.0` where deployment target supports it.
- MCP TypeScript SDK: pin **2.0.0 stable** (`@modelcontextprotocol/server` + `@modelcontextprotocol/node`), aligned to the 2026-07-28 MCP specification.

Pin versions in lockfiles. Revalidate versions before deliberate upgrades.

## 2. Canonical-state rule

The Subgraph/indexer is a read projection, never settlement authority.

Canonical state:

- ERP: source accounting record;
- IPFS/off-chain: documents/evidence;
- contracts: passport/obligation/lock/settlement state;
- Subgraph/Postgres/search: disposable projection.

Before executing locks/settlement, callers must revalidate on-chain state.

## 3. Schema is query-driven

Design `schema.graphql` from required product/MCP queries, not by mechanically mirroring every Solidity struct.

Orbitas must efficiently answer:

- get passport;
- get obligation;
- incoming/outgoing obligations by participant;
- active obligations with available quantity;
- quality observations/claims/stake summaries;
- settlement by ID;
- index health/finality;
- local A→B→C path candidates.

## 4. Immutable event entities

Use immutable entities for append-only event records where possible.

Examples:

- passport registration event;
- obligation issuance event;
- quality observation event;
- lock event;
- settlement status event.

Use mutable entities only for current-state projections such as current Participant, Obligation, Lock or SettlementInstruction.

## 5. IDs

Prefer `Bytes!` IDs for event/entity identifiers derived from transaction hashes/log indexes when human readability is not required.

Use deterministic binary concatenation rather than expensive UTF-8 string concatenation for event IDs.

Business IDs such as on-chain `uint256 obligationId` may be represented consistently as string/BigInt depending on query ergonomics, but do not mix formats across entities.


## 5.1 Ethereum integer mapping rule

Generated Subgraph event types follow The Graph type rules:

- Ethereum `uint32..uint256` and `int64..int256` map to `BigInt`;
- values smaller than `uint32` (for example `uint8`, `uint24`, `int8`) map to `i32`.

Do not wrap already-generated `uint64`/`uint256` event params with nonexistent/convenience conversions. Assign them as `BigInt` to `BigInt!` entity fields. Use `.toI32()` only when the value is explicitly bounded and the GraphQL schema intentionally uses `Int`.

## 6. Relationships

Avoid storing ever-growing arrays on parent entities.

Use `@derivedFrom` for reverse relationships where appropriate.

For graph traversal, make issuer/beneficiary fields directly filterable/indexable.

## 7. Event-first mappings

Prefer event handlers over call handlers/block handlers.

Benefits:

- deterministic;
- cheap;
- portable across supported networks;
- ABI/event-driven reconstruction.

Use block/call handlers only when the data cannot be emitted and the chosen network supports the required features.

## 8. Start block

Every data source should start at the deployment block or earliest required block. Do not index from genesis without need.

Deployment automation must export contract address + deployment block for Subgraph configuration.

## 9. Mapping determinism

AssemblyScript mappings must be deterministic.

Do not perform arbitrary network requests from mappings.

Do not depend on current wall-clock time; use block/event timestamps.

When fetching IPFS/File Data Sources, verify content model and treat it as enrichment, not settlement authority.

## 10. Current state + immutable history

Recommended pattern:

- mutable current `Obligation` entity;
- immutable `ObligationEvent`/`LockEvent`/`SettlementEvent` rows;
- current `QualityDimension` + immutable quality observation events;
- `QualityStakeSummary` grouped by `(claim, collateral)`; never blindly aggregate different collateral assets.

## 11. Query best practices

Client/MCP queries must:

- be static GraphQL documents with variables;
- request only fields needed;
- set explicit `first` limits;
- batch `id_in` queries instead of N single requests;
- avoid large `skip` pagination; use cursor/range pagination;
- avoid expensive broad `or` filters when `and`/specific queries can do the job;
- check `_meta.block` and `_meta.hasIndexingErrors` for health/freshness-sensitive operations.

## 12. The Graph abstraction

Orbitas application code should depend on an internal `ObligationIndex` interface, not The Graph-specific endpoint details.

This allows replacement/augmentation with:

- self-hosted Graph Node;
- Subgraph Network;
- RPC event indexer;
- PostgreSQL projection.

## 13. Reorg/finality

Persist or expose:

- indexed block number;
- block hash where available;
- chain head;
- lag;
- indexing errors.

Discovery can use a recent projection; settlement preparation must revalidate contract state.

## 14. Testing

Use:

- `graph codegen`;
- `graph build`;
- Matchstick mapping tests;
- fixture replay for each event;
- projection tests for partial settlement/locks;
- Q/S tests;
- indexing-error and stale-head tests.

Every new contract event must have a mapping test.

## 15. MCP server design

The MCP server is a read-only AI interface over the indexer.

Use official MCP TypeScript SDK v2 APIs:

- `McpServer`;
- `registerTool`;
- `registerResource` / `ResourceTemplate` where useful;
- `serveStdio` for local agent integrations;
- `createMcpHandler`/Streamable HTTP for remote deployment.

Do not expose arbitrary GraphQL execution to models by default.

Expose bounded domain tools instead.

## 16. MCP tool guardrails

Every MCP tool must:

- use a validated schema (Zod v4 or Standard Schema compatible);
- cap page size and path fan-out;
- use timeouts;
- return index block/freshness metadata;
- avoid secrets/API keys in output;
- distinguish projection state from canonical/final state;
- be read-only unless a separate explicitly authorized action server is designed.

## 17. Recommended MCP tools

- `orbitas_get_passport`
- `orbitas_get_obligation`
- `orbitas_list_obligations`
- `orbitas_get_incoming_obligations`
- `orbitas_get_outgoing_obligations`
- `orbitas_find_local_paths`
- `orbitas_get_settlement`
- `orbitas_index_health`

`orbitas_find_local_paths` may compute deterministic candidate paths from indexed edges but must label them as **candidates**, not executable settlements.

## 18. MCP resources

Useful read resources:

- `orbitas://passport/{id}`
- `orbitas://obligation/{id}`
- `orbitas://settlement/{id}`
- `orbitas://index/health`

Resources are read context; tools are model-invoked queries.

## 19. AI safety boundary

MCP output can inform AI reasoning, but AI must not infer that:

- indexed state is canonical;
- candidate path has participant consent;
- off-chain fulfillment happened;
- a stake changes historical observed quality;
- an obligation is legally verified merely because it is indexed.

## 20. Reference basis

This skill is synthesized from current The Graph Subgraph manifest/schema/query best-practices documentation (including immutable entities and Bytes IDs) and the MCP TypeScript SDK v2 / 2026-07-28 transport guidance.
