# TRD-03 — Obligation Smart Contract

**Status:** Draft for approval — multidimensional obligation revision 0.91  
**Depends on:** TRD-02  
**Consumed by:** TRD-04, TRD-05, ERP connectors  
**Primary decision:** one shared ERC-1155-style obligation registry/token contract; not one contract per invoice

## 1. Objective

Represent every ERP obligation published into Orbitas as an on-chain obligation token/series that can be:
- uniquely linked to its participant issuer and source evidence;
- partially locked for clearing;
- protected against double settlement;
- partially or fully settled;
- audited from issuance to settlement.

The contract supports monetary invoices AND goods/service obligations.

MVP settlement is redirect payment/fulfillment, not automatic novation.

## 2. Contract architecture

Recommended:

```text
ParticipantPassportRegistry
            │
            ▼
ObligationTokenRegistry
   ├─ obligation series / IDs
   ├─ multidimensional resource/property commitments
   ├─ outstanding quantities
   ├─ locks
   ├─ settlement instructions
   ├─ settlement completion
   └─ quality registry reference
              │
              ▼
      ObligationQualityRegistry
        ├─ quality dimensions
        ├─ observations / evidence
        ├─ quality claims
        └─ stake / guarantee registry reference
```

Use one shared contract/factory.

A pragmatic implementation may use ERC-1155 balance semantics because obligations have divisible quantity and many token IDs, but standard arbitrary transfer MUST be disabled in MVP.

Reason:
- partial settlement needs unit balances;
- each obligation is a distinct token series;
- redirect settlement must not silently become legal assignment/novation.

## 3. Obligation state

```solidity
enum ResourceType {
    MONETARY,
    GOODS,
    SERVICE
}

enum ObligationStatus {
    NONE,
    ACTIVE,
    FULLY_LOCKED,
    PARTIALLY_SETTLED,
    SETTLED,
    CANCELLED
}

struct Obligation {
    uint256 issuerPassportId;
    uint256 beneficiaryPassportId;    // 0 when counterparty not onboarded
    bytes32 externalCounterpartyHash; // optional
    ResourceType resourceType;

    // R — core resource dimensions
    bytes32 resourceCode;
    bytes32 unitCode;
    bytes32 currencyCode;

    uint256 totalQuantity;
    uint256 settledQuantity;
    uint8 decimals;

    uint64 dueDate;

    // Additional contractual/resource properties.
    // These define WHAT is promised and cannot be changed by staking.
    bytes32 propertiesHash;
    string propertiesURI;

    bytes32 sourceRefHash;
    bytes32 evidenceHash;
    bytes32 metadataHash;
    string metadataURI;

    // Q/S are maintained by the quality/stake module.
    bytes32 qualitySchemaHash;

    ObligationStatus status;
    uint64 createdAt;
}
```

Derived:

```text
outstanding = totalQuantity - settledQuantity
available = outstanding - activeLockedQuantity
```

Never store floating-point values.


## 3.1 Multidimensional obligation token — `T = (R, Q, S)`

Orbitas obligations MUST be modeled as multidimensional tokens rather than as a scalar amount alone.

The conceptual token is:

\[
T = (R,Q,S)
\]

where:

- **R — Resource / Properties Vector**: what is promised;
- **Q — Quality Vector**: how the obligation is evaluated;
- **S — Stake / Guarantee Vector**: who economically backs or challenges individual quality claims.

Equivalent obligation-state notation:

\[
\mathbf{O} =
(resource,\ quantity,\ maturity,\ location,\ properties,\
q_1,q_2,\ldots,q_n,\
s_1,s_2,\ldots,s_n)
\]

This is a protocol-level requirement, not merely metadata decoration. Clearing policies and the indexer MUST be able to reason about selected dimensions of `Q` and `S`.

### 3.1.1 Properties and qualities MUST be separated

**Properties** describe the contractual/resource object itself.

Examples:

```json
{
  "product": "wheat",
  "grade": "A",
  "origin": "BR",
  "quantity": "10",
  "unit": "ton",
  "deliveryLocation": "Santos",
  "dueDate": "2026-11-01"
}
```

Properties cannot become true because somebody stakes capital.

A stake MUST NOT be able to change:

```text
organic = false → organic = true
```

or:

```text
10 tons → 20 tons
```

Those are obligation terms and require an authorized obligation amendment/reissue process.

**Qualities** are contextual observations, assessments or forecasts about execution/acceptability.

Examples:

```text
delivery.on_time
delivery.complete
product.conformity
issuer.default_probability
invoice.dispute_probability
service.response
carbon_intensity
liquidity
```

Qualities are:
- domain-specific;
- attribute-specific;
- time-dependent;
- evidence-backed where possible;
- independently stakeable/challengeable.

### 3.1.2 The quality vector is open and key-addressable

Do NOT hard-code a global fixed list of quality fields into `Obligation`.

Use namespaced keys:

```text
keccak256("delivery.on_time")
keccak256("product.conformity")
keccak256("issuer.default_probability")
keccak256("invoice.disputes")
```

Recommended quality-state concept:

```solidity
enum QualityValueType {
    UINT,
    INT,
    BOOL,
    ENUM_HASH
}

struct QualityObservation {
    bytes32 qualityKey;
    QualityValueType valueType;

    // canonical encoded value; numeric values use fixed-point integer encoding
    bytes32 encodedValue;
    uint8 decimals;

    bytes32 sourceType;     // e.g. ERP_VERIFIED, ORACLE, COUNTERPARTY, AUDITOR
    bytes32 evidenceHash;

    uint64 observedAt;
    uint64 validUntil;
    uint32 observationCount;

    // confidence in the observation itself, not a purchased reputation score
    uint32 confidencePpm;   // 0..1_000_000
}
```

The exact storage implementation MAY be a separate `ObligationQualityRegistry`, but the quality registry is part of the obligation protocol.

### 3.1.3 Quality claims

Stake is attached to a **claim about a quality dimension**, not merely to the issuer or whole token.

Example:

> `delivery.on_time >= 0.95 until 2026-11-01`

Recommended claim:

```solidity
enum ComparisonOperator {
    EQ,
    NE,
    GT,
    GTE,
    LT,
    LTE
}

struct QualityClaim {
    uint256 obligationId;
    bytes32 qualityKey;
    ComparisonOperator operator;
    int256 threshold;
    uint8 decimals;

    bytes32 contextHash;
    uint64 validUntil;
    bytes32 evidenceHash;
}
```

`contextHash` MAY bind the claim to:
- geography;
- delivery window;
- product specification;
- particular obligation tranche;
- other claim-specific context.

### 3.1.4 Independent FOR / AGAINST stake

For each quality claim, participants may independently stake **FOR** or **AGAINST**.

Concept:

```solidity
enum StakeSide {
    FOR,
    AGAINST
}

struct QualityStakePosition {
    bytes32 claimId;
    uint256 stakerPassportId;
    address collateralToken;
    uint256 amount;
    StakeSide side;
    uint64 lockedUntil;
}
```

Examples of attribute-specific guarantors:

| Staker | Example backed dimension |
|---|---|
| supplier | `fulfillment.complete` |
| logistics provider | `delivery.on_time` |
| insurer | `issuer.default_probability` / delivery default |
| laboratory | `product.conformity` |
| bank / ERP attestor | turnover / solvency-related observation |
| customer | observed delivery/service quality |
| ESG auditor | carbon/resource quality dimension |

Thus one obligation can accumulate a distributed guarantee layer instead of one global reputation score.

### 3.1.5 Staking MUST NOT rewrite observed history

This invariant is critical.

Do NOT implement:

```text
observedQuality = observedQuality + stake
```

Otherwise a wealthy participant could purchase a fictitious reputation.

Maintain separate concepts:

```text
Q_observed = evidence-derived observation
S_positive = capital supporting a quality claim
S_negative = capital challenging a quality claim
Q_effective = policy-specific interpretation of Q_observed + S
```

The obligation protocol exposes observations and stake/guarantee state.

It MUST NOT define one universal `Q_effective` score for all counterparties.

Each participant/consent policy decides how much weight to give:
- observed quality;
- evidence confidence;
- FOR stake;
- AGAINST stake;
- collateral asset;
- staker identity/reputation;
- stake duration.

### 3.1.6 Staking changes acceptability, not truth

The intended economic mechanism is:

```text
Capital
   ↓
attribute-specific economic backing
   ↓
higher/lower confidence in a claim
   ↓
counterparty policy acceptability
   ↓
more/fewer executable clearing paths
```

A positive stake can therefore make an obligation acceptable under a participant policy even when its raw observed quality alone would not meet that policy.

Negative stake can make the obligation less acceptable.

Example:

```text
Observed:
  issuer.default_quality = 0.72

Receiver policy:
  accept if quality >= 0.80
  OR
  quality >= 0.70 AND approved collateral coverage >= 30%

Third-party stake:
  approved guarantee coverage = 35%
```

The path may become eligible because the **policy** accepts the combination.

The contract does not mutate `0.72` into `0.84`.

### 3.1.7 Quality/stake protocol interface

Recommended modular interface:

```solidity
interface IObligationQualityRegistry {
    function getObservation(
        uint256 obligationId,
        bytes32 qualityKey
    ) external view returns (QualityObservation memory);

    function getClaim(
        bytes32 claimId
    ) external view returns (QualityClaim memory);

    function stakeSummary(
        bytes32 claimId,
        address collateralToken
    ) external view returns (
        uint256 forAmount,
        uint256 againstAmount
    );

    function qualityKeys(
        uint256 obligationId
    ) external view returns (bytes32[] memory);
}
```

The core `ObligationTokenRegistry` stores the active `qualityRegistry` address or obtains it through protocol configuration.

### 3.1.8 Quality schema and metadata

`qualitySchemaHash` commits to the set/schema of dimensions understood for the obligation.

Off-chain quality metadata MAY use the following shape:

```json
{
  "schemaVersion": "1.0",
  "qualities": {
    "delivery.on_time": {
      "value": 0.93,
      "source": "ERP_VERIFIED",
      "timestamp": "2026-09-01T00:00:00Z",
      "observations": 183,
      "confidence": 0.97,
      "claims": [
        {
          "operator": ">=",
          "threshold": 0.95,
          "claimId": "0x..."
        }
      ]
    }
  }
}
```

The indexer may enrich this with stake summaries:

```json
{
  "positiveStake": [
    {"asset": "0x...", "amount": "100000"}
  ],
  "negativeStake": [
    {"asset": "0x...", "amount": "5000"}
  ]
}
```

Stake values in different collateral assets MUST NOT be blindly added together without an explicit valuation rule.

### 3.1.9 Property mutation

If an amendment changes a property that materially changes what is owed, the implementation SHOULD:
- version/reissue the obligation; or
- record an explicit amendment accepted by required parties.

Quality observations may evolve without changing the underlying economic promise.

This distinction allows a stable obligation identity while its evidence and trust vector evolve.

### 3.1.10 Clearing integration

TRD-05 must evaluate:

\[
Path_{eligible}
=
Path_{graph}
\cap
ResourceConstraints
\cap
QualityConstraints
\cap
ConsentConstraints
\]

A graph edge is therefore not only:

```text
e = (A, B, amount)
```

but conceptually:

```text
e = (A, B, R, Q, S)
```

This is the required bridge between multidimensional obligations and path-enabled clearing.


## 4. Source reference

`sourceRefHash` MUST deterministically commit to the ERP source identity, e.g.:

```text
hash(
  connectorType,
  tenantId,
  sourceRecordType,
  sourceRecordId,
  sourceVersion
)
```

The contract SHOULD reject duplicate issuance for the same currently-active source reference when the connector intends a single canonical token.

Use a mapping:

```solidity
mapping(bytes32 => uint256) obligationBySourceRef;
```

Versioning/reissue rules must be explicit; do not mint duplicate economic claims on retries.

## 5. Beneficiary onboarding states

### Registered beneficiary

`beneficiaryPassportId > 0`

Clearing eligible if all other requirements pass.

### External/unclaimed beneficiary

`beneficiaryPassportId == 0`
`externalCounterpartyHash != 0`

Purpose:
- allow an ERP participant to tokenize an obligation before the counterparty joins Orbitas.

Rules:
- unclaimed obligation is indexable;
- it is NOT eligible for P2P clearing that requires counterparty consent;
- later binding to a passport requires a signed/connector-backed claim process;
- binding does not change the underlying economic obligation.

MVP implementation MAY postpone claim UX, but schema must not make unregistered ERP counterparties impossible.

## 6. Issuance

### `issueObligation`

Input:

```solidity
struct IssueInput {
    uint256 issuerPassportId;
    uint256 beneficiaryPassportId;
    bytes32 externalCounterpartyHash;
    ResourceType resourceType;
    bytes32 resourceCode;
    bytes32 unitCode;
    bytes32 currencyCode;
    uint256 quantity;
    uint8 decimals;
    uint64 dueDate;

    bytes32 propertiesHash;
    string propertiesURI;

    bytes32 sourceRefHash;
    bytes32 evidenceHash;
    bytes32 metadataHash;
    string metadataURI;

    bytes32 qualitySchemaHash;
}
```

Authorization:
- active issuer passport;
- issuer controller/operator OR valid typed issuer intent.

Rules:
- quantity > 0;
- due date valid according to product rule;
- evidence/source hashes non-zero;
- sourceRef duplicate prevention.

Output:
- `obligationId`.

## 7. Token semantics

If ERC-1155 is used:
- token ID = `obligationId`;
- minted balance = `totalQuantity`;
- balance is associated with the fixed beneficiary when registered;
- arbitrary `safeTransferFrom` / `safeBatchTransferFrom` MUST revert in MVP unless a future legal transfer feature is explicitly enabled;
- settlement burns/reduces balances only after settlement confirmation.

If beneficiary is unclaimed:
- quantity may be held in a protocol claim vault or represented only in obligation accounting until bound;
- path search excludes it.

The implementation MUST prioritize legal/product semantics over strict token-standard purity.

## 8. Locks

```solidity
struct Lock {
    bytes32 settlementId;
    uint256 quantity;
    uint64 expiresAt;
    bool active;
}
```

Requirements:
- multiple non-overlapping locks MAY exist up to available quantity;
- total locked + settled must never exceed total;
- lock creation is idempotent by `(obligationId, settlementId)`;
- expired/failed settlement locks can be released;
- finalized settlement lock cannot be reused.

Functions:

- `lockForSettlement(obligationId, settlementId, quantity, expiry, consentProofHash, authorization)`
- `releaseLock(obligationId, settlementId)`
- `availableQuantity(obligationId)`

## 9. Redirect settlement instruction

The contract records settlement instruction state without novating the original claim.

```solidity
struct SettlementInstruction {
    bytes32 settlementId;
    uint256 payerPassportId;
    uint256 receiverPassportId;
    ResourceType resourceType;
    bytes32 resourceCode;
    bytes32 unitCode;
    bytes32 currencyCode;
    uint256 quantity;
    uint8 decimals;
    uint64 dueDate;
    bytes32 sourceSetHash;
    bytes32 consentProofHash;
    bytes32 fulfillmentEvidenceHash;
    SettlementStatus status;
}
```

The full list of source obligation IDs MAY be emitted in events or stored off-chain with `sourceSetHash` if gas/storage is excessive.

## 10. Settlement state machine

```text
ACTIVE obligation
   │
   ├── lock
   ▼
LOCKED / partially locked
   │
   ├── settlement fails/expires → release → ACTIVE
   │
   └── settlement confirmed
             │
             ▼
      reduce outstanding
             │
      ┌──────┴──────┐
      ▼             ▼
PARTIAL         SETTLED
```

Settlement instruction:

```text
PROPOSED → LOCKED → EXECUTING → SETTLED
                    └────────→ FAILED → locks released
```

On-chain states MAY be collapsed, but business semantics must be preserved.

## 11. Settlement confirmation modes

Orbitas obligations can be discharged by different real-world mechanisms.

The contract must support a generic confirmation proof:

### On-chain atomic asset settlement
Contract or settlement adapter can verify transaction execution.

### Off-chain fiat/goods/service settlement
Completion is recorded only after the required signed participant/ERP confirmation or approved evidence workflow.

The smart contract MUST NOT falsely assert that an off-chain bank payment or physical delivery occurred merely because a proposal was created.

## 12. Events

Minimum stable events:

```solidity
event ObligationIssued(...);
event ObligationMetadataUpdated(...);
event ObligationCounterpartyBound(...);

event ObligationLocked(
    uint256 indexed obligationId,
    bytes32 indexed settlementId,
    uint256 quantity,
    uint64 expiresAt
);

event ObligationLockReleased(...);

event SettlementInstructionCreated(
    bytes32 indexed settlementId,
    uint256 indexed payerPassportId,
    uint256 indexed receiverPassportId,
    uint256 quantity,
    bytes32 sourceSetHash,
    bytes32 consentProofHash
);

event SettlementInstructionStatusChanged(...);

event ObligationSettled(
    uint256 indexed obligationId,
    bytes32 indexed settlementId,
    uint256 quantity,
    uint256 remainingQuantity
);

event ObligationCancelled(...);
```

Event parameter lists must be finalized together with TRD-04 schema before contract freeze.

## 13. Cancellation

An obligation MAY be cancelled only according to a strict rule:
- no active lock;
- no settled amount that would be erased;
- authorized issuer;
- cancellation event persists history.

If original ERP obligation is cancelled after partial settlement, only residual may be cancelled.

## 14. Multidimensional quality/stake module

The `T=(R,Q,S)` model defined in §3.1 is part of the Obligation protocol.

The core obligation contract MUST expose or reference an `IObligationQualityRegistry`.

### MVP boundary

Required now:
- obligation properties vector `R`;
- open quality-key schema `Q`;
- ability to attach evidence-backed quality observations;
- ability to identify quality claims;
- protocol interface for FOR/AGAINST stake summaries;
- events/indexing hooks for quality state;
- clearing policy access to `Q` and `S`.

May be implemented as a minimal/zero-balance staking module in the first release if collateral economics are not yet activated.

Not yet fixed by this TRD:
- reward curve;
- slashing formula;
- dispute resolver;
- oracle governance;
- cross-collateral valuation;
- universal effective quality formula.

Those require a dedicated `Quality Stake / Attribute Bond TRD` before real collateral is put at risk.

### Required events

At minimum, the quality module must be capable of emitting:

```solidity
event QualityObservationRecorded(
    uint256 indexed obligationId,
    bytes32 indexed qualityKey,
    bytes32 encodedValue,
    uint8 decimals,
    bytes32 sourceType,
    bytes32 evidenceHash,
    uint64 observedAt,
    uint64 validUntil,
    uint32 confidencePpm
);

event QualityClaimCreated(
    bytes32 indexed claimId,
    uint256 indexed obligationId,
    bytes32 indexed qualityKey,
    uint8 operator,
    int256 threshold,
    uint8 decimals,
    uint64 validUntil
);

event QualityStakeChanged(
    bytes32 indexed claimId,
    uint256 indexed stakerPassportId,
    address indexed collateralToken,
    uint8 side,
    uint256 amount,
    uint256 newPosition
);

event QualityClaimResolved(
    bytes32 indexed claimId,
    bytes32 resolution,
    bytes32 evidenceHash
);
```

TRD-04 must index these events.

## 15. Security invariants

1. `settled + locked <= total`.
2. Same ERP source version cannot be minted twice through retries.
3. No arbitrary token transfer in MVP.
4. Only active issuer passport/controller/operator can issue.
5. Settlement cannot settle more than the locked amount.
6. Releasing a lock cannot increase available amount above outstanding.
7. Cancellation cannot erase settled history.
8. Signed intents cannot be replayed.
9. Contract does not fetch/interpret IPFS content on-chain.
10. Indexer state is never trusted for contract authorization.
11. Stake MUST NOT modify the evidence-derived observed quality value.
12. A quality stake is scoped to `(obligationId, qualityKey, claimId)` and cannot silently guarantee unrelated dimensions.
13. Property changes cannot be performed through quality/stake functions.
14. Stake values in different collateral assets are not aggregated without an explicit valuation rule.
15. Quality observations and claims remain historically auditable after settlement.

## 16. Tests

Required:
- issue monetary obligation;
- issue goods obligation;
- issue service obligation;
- duplicate sourceRef rejection;
- partial lock;
- concurrent lock limit;
- lock expiry/release;
- partial settlement;
- full settlement;
- failed settlement release;
- arbitrary transfer revert;
- unclaimed counterparty excluded/bound;
- signed intent replay;
- fuzz invariant `settled + locked <= total`;
- event completeness for indexer;
- property vector hash/URI commitment;
- quality observation add/update;
- multiple independent quality keys;
- FOR and AGAINST stake scoped to one claim;
- stake cannot mutate observed quality;
- claim on one quality cannot affect another quality;
- different collateral assets remain separate;
- quality events reconstructable by indexer.

## 17. Acceptance criteria

- ERP plugin can idempotently issue one tokenized representation per published ERP obligation.
- Contract supports partial quantities.
- Contract blocks double consumption.
- Path settlement can lock and settle multiple source obligations with one `settlementId`.
- Redirect instruction is recorded without transferring the original obligation token as legal assignment.
- TRD-04 can reconstruct active/locked/settled state entirely from chain events plus calls.
- An obligation can expose a multidimensional `T=(R,Q,S)` state.
- `R` properties, observed `Q`, and staked/guaranteed `S` remain separate protocol dimensions.
- A clearing policy can query selected quality observations and attribute-specific stake without relying on one global reputation score.
