# TRD-04 — Obligation Indexer and Search Projection

**Status:** Draft for approval — multidimensional obligation revision 0.91  
**Depends on:** TRD-02, TRD-03  
**Consumed by:** TRD-05, ERP connectors, UI  
**Preferred technology:** The Graph where the selected chain is supported; custom Orbitas indexer remains the product abstraction

## 1. Objective

Create a read-optimized, re-buildable index of participant passports, tokenized obligations, locks and settlement events.

The indexer enables:
- obligation discovery;
- participant-neighborhood queries;
- path discovery;
- UI lists/status;
- connector reconciliation;
- analytics.

It is NEVER the canonical source of financial state.

## 2. Architecture

Recommended two-stage architecture:

```text
EVM contracts
     │ events
     ▼
The Graph Subgraph
(or chain event adapter)
     │
     ▼
Orbitas Indexer Service
     ├── PostgreSQL
     ├── Search index (optional MVP)
     └── Graph projection / adjacency store
             │
             ▼
       Clearing Path Service
```

The Graph is valuable because a Subgraph maps contract events into queryable entities and exposes GraphQL.

However:
- selected L2/network support must be validated;
- The Graph must not be the only storage/query abstraction;
- Orbitas code must depend on `ObligationIndex` interface, not The Graph-specific details.

## 3. Indexer interfaces

```typescript
interface ObligationIndex {
  getPassport(passportId): Promise<PassportProjection>;
  getObligation(obligationId): Promise<ObligationProjection>;
  listObligations(filter): Promise<Page<ObligationProjection>>;
  getIncoming(passportId, filter): Promise<ObligationProjection[]>;
  getOutgoing(passportId, filter): Promise<ObligationProjection[]>;
  getSettlement(settlementId): Promise<SettlementProjection>;
  getSyncStatus(): Promise<IndexSyncStatus>;
}
```

TRD-05 MUST consume this interface.

## 4. Indexed entities

### Passport

- passportId
- controller
- metadataHash
- metadataURI
- status
- createdAt
- updatedAt

### Obligation

- obligationId
- issuerPassportId
- beneficiaryPassportId
- externalCounterpartyHash
- resourceType
- resourceCode
- unitCode
- currencyCode
- totalQuantity
- settledQuantity
- lockedQuantity
- availableQuantity
- decimals
- dueDate
- sourceRefHash
- evidenceHash
- metadataHash
- metadataURI
- propertiesHash
- propertiesURI
- qualitySchemaHash
- status
- block/tx provenance

### QualityObservationProjection

- obligationId
- qualityKey
- valueType
- encodedValue
- decimals
- sourceType
- evidenceHash
- observedAt
- validUntil
- observationCount
- confidencePpm
- block/tx provenance

### QualityClaimProjection

- claimId
- obligationId
- qualityKey
- operator
- threshold
- decimals
- contextHash
- validUntil
- evidenceHash
- resolution/status

### QualityStakeProjection

- claimId
- stakerPassportId
- collateralToken
- side (`FOR` / `AGAINST`)
- amount/currentPosition
- lockedUntil
- status
- block/tx provenance

The indexer MUST NOT aggregate stake positions in different collateral assets into one economic number unless an explicit valuation rule is configured.

### ObligationLock

- obligationId
- settlementId
- quantity
- expiresAt
- status
- txHash
- blockNumber

### SettlementInstruction

- settlementId
- payerPassportId
- receiverPassportId
- resource fields
- quantity
- dueDate
- sourceSetHash
- consentProofHash
- status
- fulfillmentEvidenceHash
- tx provenance

### SettlementObligationLink

Because one settlement may affect multiple obligations:
- settlementId
- obligationId
- quantityApplied
- direction/role

## 5. The Graph subgraph

If used, define:

- `subgraph.yaml`
- `schema.graphql`
- event mappings
- contract start blocks
- deployed chain name
- versioned ABI

Minimum event handlers:
- PassportRegistered
- PassportMetadataUpdated
- PassportControllerChanged
- PassportDeactivated
- ObligationIssued
- ObligationCounterpartyBound
- ObligationLocked
- ObligationLockReleased
- SettlementInstructionCreated
- SettlementInstructionStatusChanged
- ObligationSettled
- ObligationCancelled
- QualityObservationRecorded
- QualityClaimCreated
- QualityStakeChanged
- QualityClaimResolved

The Subgraph schema must be generated from finalized TRD-02/TRD-03 events, not guessed independently.

## 6. Custom Orbitas indexer

Responsibilities:
- ingest Subgraph or RPC event stream;
- normalize chain data into internal projections;
- enrich with allowed public metadata;
- maintain search indexes;
- build directed obligation adjacency;
- offer stable API independent of indexing backend;
- handle caching and query authorization.

Recommended MVP persistence:
- PostgreSQL as durable projection;
- optional OpenSearch/Meilisearch only if text/filter needs justify it;
- graph adjacency can initially use relational indexes/in-memory structures;
- dedicated graph database is an optimization, not an MVP dependency.

This preserves the earlier project direction of PostgreSQL + search + graph capabilities without prematurely requiring three databases.

## 7. Directed obligation graph

Graph semantics:

```text
node = passportId
edge = active clearing-eligible obligation
direction = debtor/issuer → creditor/beneficiary
edge state = (R, Q, S)
R = resource/property vector
Q = indexed quality observations/claims
S = attribute-specific stake/guarantee positions
weight = available quantity/value for the current clearing dimension
```

Only obligations with:
- registered participants at required endpoints;
- status allowing clearing;
- positive available quantity;
- non-expired eligibility

are exposed to the default clearing graph.

Unclaimed external-counterparty obligations remain searchable but are excluded from executable path adjacency.

## 8. Search API

### `GET /v1/index/obligations`

Filters:
- issuerPassportId
- beneficiaryPassportId
- resourceType
- resourceCode
- currencyCode
- dueBefore/dueAfter
- status
- minAvailableQuantity
- metadata tags if public
- qualityKey
- quality numeric/range predicate where indexable
- qualitySourceType
- minConfidencePpm
- claimId
- stakeSide
- collateralToken
- minStakeAmount

### `GET /v1/index/passports/{passportId}/incoming`

Returns incoming active obligations.

### `GET /v1/index/passports/{passportId}/outgoing`

Returns outgoing active obligations.

### `GET /v1/index/settlements/{settlementId}`

### GraphQL

May expose equivalent query model if The Graph is directly used by clients, but public application code should prefer Orbitas API for backend portability and policy enforcement.

## 9. Privacy

Indexer MUST NOT automatically ingest:
- full invoice documents;
- contracts;
- confidential line-item descriptions;
- ERP authentication credentials.

It MAY ingest public metadata referenced by obligation token only when:
- metadata is explicitly marked publishable;
- content hash matches on-chain metadataHash.

Private metadata remains available through participant-local connector/agent APIs.

## 10. Reorg and finality behavior

Indexer must distinguish:
- observed event;
- confirmed/finalized projection.

Requirements:
- persist block number/hash;
- detect chain reorg where supported;
- roll back orphaned projection rows;
- configurable finality depth/network finality policy;
- UI/clearing service must know whether indexed state is final enough for proposal vs settlement.

Before locking, TRD-03 contract state MUST be revalidated directly; an index snapshot alone is insufficient.

## 11. Idempotency

Unique event key:

`(chainId, txHash, logIndex)`

Repeated ingestion must not duplicate entities or quantities.

Projection rebuild from genesis/startBlock must produce the same state.

## 12. Sync lag

Expose:

```json
{
  "chainHead": 123,
  "indexedBlock": 120,
  "lagBlocks": 3,
  "status": "HEALTHY"
}
```

TRD-05 must reject/flag discovery from stale index according to configured threshold.

## 13. Observability

Metrics:
- latest indexed block;
- lag blocks/time;
- events/sec;
- projection errors;
- metadata hash failures;
- GraphQL/RPC latency;
- query latency p50/p95/p99;
- number of active obligation edges;
- number of unclaimed obligations.

Alerts:
- index stopped;
- reorg rollback error;
- projection invariant mismatch;
- contract ABI/event mismatch.

## 14. Testing

- replay historical event fixture;
- rebuild projection deterministically;
- duplicate event idempotency;
- reorg fixture rollback;
- partial settlement updates available quantity;
- lock/release updates;
- unclaimed obligation exclusion from active graph;
- multidimensional quality observations reconstructed;
- FOR/AGAINST stake projections remain claim-scoped;
- different collateral assets not blindly summed;
- metadata hash mismatch not trusted;
- index lag surfaced;
- direct-contract revalidation path in TRD-05.

## 15. Acceptance criteria

- UI can list passports/obligations without direct chain scanning.
- Clearing service can query incoming/outgoing edges by participant.
- Index can be fully rebuilt from chain events.
- Indexer failure cannot corrupt canonical contract state.
- The Graph can be replaced by another event adapter without changing TRD-05 public interface.
