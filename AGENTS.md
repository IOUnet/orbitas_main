# AGENTS.md — Orbitas

**Version:** 1.0 Development Baseline  
**Date:** 2026-09-02  
**Audience:** AI development agents, architects, backend/blockchain/integration engineers, reviewers and release agents  
**Project:** Orbitas  
**Primary MVP:** P2P clearing network for ERP-backed tokenized business obligations

---

# 0. Purpose and authority of this file

This file is the root operating contract for AI agents developing Orbitas.

Agents MUST use it to understand:

- what Orbitas is;
- what the MVP is;
- which decisions are already approved;
- which decisions remain open;
- which components own which state;
- what the core domain model is;
- what MUST NOT be added to MVP without explicit approval;
- which TRD governs each subsystem;
- how to change product or protocol behavior safely.

This file is intentionally self-contained enough for an agent with limited context to work correctly.

It does **not** replace detailed PRD/TRD/SRS artifacts.

## 0.1 Source precedence

When documents disagree, use this precedence:

1. **Latest explicit user decision**
2. **This `AGENTS.md`**
3. Approved BRD decisions
4. Current PRD
5. Current TRDs
6. SRS / implementation plans generated from those TRDs
7. Existing code behavior
8. Comments / stale documentation

Existing code is NOT allowed to silently override an approved product decision.

If code conflicts with this file, the agent MUST flag the conflict.

## 0.2 Required downstream document tree

Recommended repository layout:

```text
/
├─ AGENTS.md
├─ docs/
│  ├─ product/
│  │  └─ PRD_Orbitas_MVP.md
│  ├─ trd/
│  │  ├─ TRD-01-participant-passport-issuance.md
│  │  ├─ TRD-02-participant-passport-smart-contract.md
│  │  ├─ TRD-03-obligation-smart-contract.md
│  │  ├─ TRD-04-obligation-indexer.md
│  │  ├─ TRD-05-clearing-path-discovery.md
│  │  ├─ TRD-06-orbitas-odoo-plugin.md
│  │  ├─ TRD-07-orbitas-quickbooks-plugin.md
│  │  └─ TRD-08-orbitas-1c-enterprise-plugin.md
│  ├─ srs/
│  ├─ adr/
│  └─ runbooks/
└─ ...
```

Current technical package version underlying this file: **TRD package v0.91**.

---

# 1. Product contract

## 1.1 One-sentence definition

> **Orbitas is a P2P clearing network that connects to business ERP/accounting systems, tokenizes ERP-backed monetary and resource obligations on-chain, discovers path-enabled clearing opportunities under participant-defined consent policies, coordinates settlement, and writes the result back into the source ERP.**

## 1.2 Core product sequence

```text
ERP
 ↓
Participant Passport
 ↓
ERP-backed Obligation
 ↓
On-chain Obligation Token
 ↓
Indexer / local obligation graph
 ↓
Path-enabled Clearing Discovery
 ↓
Consent Policy Evaluation
 ↓
Locks
 ↓
P2P Redirect Settlement
 ↓
Settlement Finality
 ↓
ERP Reconciliation
 ↓
Billing on Successfully Settled Value
```

## 1.3 Business thesis

Orbitas solves liquidity mismatch **before** adding financing.

The default order is:

```text
CLEAR FIRST
    ↓
SETTLE WHAT CAN BE SETTLED
    ↓
FINANCE ONLY THE RESIDUAL
```

MVP stops primarily at clearing and reconciliation.

Factoring, lending and RWA are later-stage products.

## 1.4 What Orbitas is NOT

Orbitas MVP is not:

- a replacement ERP;
- a bank;
- a factoring company;
- a central clearing house acting as principal;
- a public DEX;
- a public AMM;
- a crypto speculation platform;
- a universal credit bureau;
- a freelancer reputation product;
- a SocialFi product;
- a global DAO;
- a new accounting system.

---

# 2. Approved product decisions

The following decisions are approved and MUST NOT be reopened silently.

| ID | Decision |
|---|---|
| PD-01 | Production clearing supports **monetary invoices AND goods/service obligations** |
| PD-02 | Settlement instruction is **redirect payment / redirect fulfillment**, not automatic legal novation |
| PD-03 | Consent is driven by **pre-defined machine-readable consent policies**, with manual exception flow where required |
| PD-04 | MVP settlement model is **P2P** |
| PD-05 | Generalized minimum verification/admission score is **out of MVP** |
| PD-06 | Every ERP obligation **published for clearing is tokenized on-chain** |
| PD-07 | Canonical state is hybrid: **ERP + off-chain/IPFS evidence + on-chain token/settlement state** |
| PD-08 | Initial jurisdiction is TBD; preferred exploration: **Mexico, Brazil, Peru** |
| PD-09 | Charging event = **Successfully Settled Value** |
| PD-10 | **Path-enabled clearing is sufficient**; a separate cycle optimizer is not required for MVP |
| PD-11 | Participant passport issuance is **self-service**; no administrator approval is required in MVP |
| PD-12 | Participant passport MVP uses self-declared company data and website; profile is not treated as KYB-verified |
| PD-13 | Obligation is a **multidimensional token** with resource/properties, quality, and stake/guarantee dimensions |
| PD-14 | Staking does **not rewrite observed quality/reputation history**; it changes economic backing/acceptability under participant policy |

---

# 3. Open decisions — agents MUST NOT decide silently

These are intentionally open.

## OD-01 — First production jurisdiction

Candidates:
- Mexico
- Brazil
- Peru

Core protocol MUST remain jurisdiction-neutral.

Jurisdiction-specific:
- accounting treatment;
- redirect-payment wording;
- tax/e-invoice behavior;
- legal enforceability;
- settlement documents

must live in country/configuration modules.

## OD-02 — Unlike-resource equivalence

For:

```text
A owes B: 10 tons steel
B owes C: 100 engineering hours
```

resources are NOT automatically fungible.

Current safe baseline:

- explicit participant-defined equivalence/acceptance; or
- manually approved specific quote.

Agents MUST NOT invent a global price, AMM rate or LLM-derived conversion.

## OD-03 — Active staking economics

The multidimensional token includes a quality/stake protocol model, but the following are not approved:

- reward curve;
- slashing formula;
- claim-resolution oracle;
- dispute adjudication;
- collateral valuation across assets;
- global effective score.

Do not put real participant collateral at risk until a dedicated Quality Stake / Attribute Bond TRD is approved.

## OD-04 — Exact blockchain/L2

Current architecture assumes an EVM-compatible smart-contract environment because the protocol interfaces are Solidity/EVM-oriented.

The exact chain/L2 remains configurable.

## OD-05 — QuickBooks product target

TRD-07 currently assumes **QuickBooks Online**.

Do not add QuickBooks Desktop unless explicitly approved.

## OD-06 — First certified 1C configuration

TRD-08 is platform-level.

Implementation planning must choose one or more certified profiles, such as:
- 1C:ERP;
- 1C:Бухгалтерия;
- 1C:Управление торговлей.

---

# 4. Core design principles

## P-01 — Clear first

Always test clearing before adding financing logic.

## P-02 — ERP-native

Orbitas does not replace the accounting system.

## P-03 — P2P economic topology

Orbitas software may operate hosted infrastructure, but Orbitas MUST NOT become debtor, creditor, buyer, seller or settlement principal merely to make the architecture easier.

## P-04 — Deterministic financial state

Final obligation quantities, locks, consent results and settlements must be determined by deterministic rules.

## P-05 — AI is advisory

AI can improve discovery and usability, but cannot create financial truth.

## P-06 — Minimum disclosure

Do not require the full business graph or full ERP to become public.

## P-07 — On-chain obligation state

Every published clearing obligation has an on-chain representation.

## P-08 — Off-chain documents

Full invoices/contracts/evidence are off-chain/IPFS or equivalent.

## P-09 — Indexers are projections

The Graph/PostgreSQL/search stores are never authoritative for settlement authorization.

## P-10 — Idempotency everywhere

Retries must not:
- mint duplicate obligations;
- create duplicate accounting entries;
- settle the same amount twice;
- create duplicate billing events.

## P-11 — Extensibility without premature scope

The domain model must support long-term Resourceconomy use cases without implementing them in MVP.

---

# 5. System architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│                         ERP / Accounting                           │
│       Odoo              QuickBooks Online           1C             │
└────────┬────────────────────┬────────────────────────┬──────────────┘
         │                    │                        │
         ▼                    ▼                        ▼
┌────────────────────────────────────────────────────────────────────┐
│                      ERP Connector Layer                           │
│   normalization • evidence • idempotency • write-back             │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                    Participant / Local Agent                       │
│ passport • consent policy • signing • local private context        │
└─────────────┬───────────────────────────────────────┬──────────────┘
              │                                       │
              ▼                                       ▼
┌──────────────────────────┐              ┌──────────────────────────┐
│ Participant Passport     │              │ Evidence / Metadata      │
│ Smart Contract           │              │ IPFS / off-chain         │
└─────────────┬────────────┘              └──────────────────────────┘
              │
              ▼
┌────────────────────────────────────────────────────────────────────┐
│                  Obligation Protocol                              │
│ Obligation token • R/Q/S • locks • settlement instructions        │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ events
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                Indexer / Obligation Projection                    │
│ The Graph optional backend • Orbitas index API • adjacency         │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                  Clearing Path Service                            │
│ deterministic paths • resource compatibility • Q/S constraints    │
│ consent policy • optional AI ranking/explanation                  │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                 P2P Settlement Orchestration                      │
│ revalidation • locks • signatures • finality                      │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
               ┌───────────────┴────────────────┐
               ▼                                ▼
        On-chain final state             ERP reconciliation
```

---

# 6. Canonical state boundaries

There is no single global database that owns all truth.

## 6.1 ERP is canonical for

- original invoice;
- bill;
- order;
- service/goods record;
- accounting entries;
- original counterparty;
- source record history.

## 6.2 Off-chain/IPFS is canonical for

- invoice PDF/XML;
- contract;
- purchase order payload;
- specification;
- delivery evidence;
- service acceptance evidence;
- large/private metadata.

## 6.3 On-chain contracts are canonical for

- participant passport existence/controller;
- published obligation identity;
- tokenized quantity/value;
- source/evidence commitments;
- lock state;
- settlement instruction state;
- settled quantity;
- quality claims/events where protocolized;
- stake/guarantee state where enabled.

## 6.4 Indexers are canonical for nothing

Indexers are:
- disposable;
- re-buildable;
- optimized for reads.

Before settlement/locking, canonical contract state MUST be revalidated.

---

# 7. Shared identifiers and numeric conventions

## 7.1 IDs

```text
passportId    uint256
obligationId  uint256
proposalId    bytes32
settlementId  bytes32
claimId       bytes32
qualityKey    bytes32
```

## 7.2 ERP source identity

Canonical external source tuple:

```text
(connectorType, tenantId, sourceRecordType, sourceRecordId, sourceVersion)
```

Recommended:

```text
sourceRefHash =
keccak256/canonicalHash(
  connectorType,
  tenantId,
  sourceRecordType,
  sourceRecordId,
  sourceVersion
)
```

## 7.3 Never use floating point for economic state

Use:

```text
quantity: uint256
decimals: uint8
unitCode: bytes32
currencyCode: bytes32
```

Examples:

```text
BRL 1,234.56
quantity = 123456
decimals = 2
currency = BRL

12.5 kg
quantity = 125
decimals = 1
unit = kg
```

Quality numeric values should also use explicit fixed-point integer encoding.

---

# 8. Participant Passport

Governed by:

- `TRD-01-participant-passport-issuance.md`
- `TRD-02-participant-passport-smart-contract.md`

## 8.1 MVP user flow

User:

1. connects controller wallet;
2. enters/confirms company data;
3. provides company website;
4. signs registration;
5. receives `passportId`.

No administrator approval.

No mandatory KYB.

## 8.2 Minimal user-entered profile

Required product data:

```json
{
  "companyName": "Example LLC",
  "website": "https://example.com"
}
```

Optional:
- legal name;
- country;
- registration number;
- tax ID;
- email;
- description.

Optional fields MUST NOT block MVP issuance unless a later jurisdiction module requires them.

## 8.3 Verification status

MVP passport is:

```text
SELF_DECLARED
```

Do not call it verified/KYB-verified.

## 8.4 Passport contract

Preferred model:

```text
ParticipantPassportRegistry
```

One shared registry, not one contract per company.

Properties:
- stable `passportId`;
- current controller;
- metadata hash/URI;
- active/deactivated status;
- scoped operators.

Passport is identity, not a freely tradable asset.

## 8.5 Operators

ERP connector/agent may be granted scoped permissions, e.g.:

```text
ISSUE_OBLIGATION
UPDATE_OBLIGATION_METADATA
PROPOSE_SETTLEMENT
CONFIRM_SETTLEMENT
```

Do not grant blanket ownership authority to connectors.

## 8.6 Controller rotation

Passport ID remains stable.

Current controller can rotate controller.

Lost-key recovery is not yet solved unless explicitly scoped.

---

# 9. Obligation — the central protocol object

Governed by:

- `TRD-03-obligation-smart-contract.md`

## 9.1 Every published obligation is tokenized

For MVP:

```text
ERP obligation
   ↓
normalized Orbitas obligation
   ↓
evidence commitment
   ↓
on-chain obligationId/token
```

Do not create one smart contract per invoice.

Use one shared registry/token protocol.

A practical implementation may use ERC-1155-style multi-token semantics.

Arbitrary token transfer MUST be disabled in MVP unless a later legal-transfer feature is approved.

## 9.2 Obligation types

```text
MONETARY
GOODS
SERVICE
```

The core schema MUST NOT assume:

```text
obligation = amount + currency
```

## 9.3 Multidimensional token model

Every obligation is conceptually:

\[
T = (R,Q,S)
\]

where:

### `R` — Resource / Properties Vector

What is promised.

Examples:
- resource type;
- quantity;
- unit;
- currency;
- product grade;
- origin;
- location;
- due date;
- specification.

### `Q` — Quality Vector

Evidence-derived, contextual qualities/claims.

Examples:

```text
delivery.on_time
delivery.complete
product.conformity
issuer.default_probability
invoice.disputes
service.response
carbon_intensity
liquidity
```

### `S` — Stake / Guarantee Vector

Attribute-specific economic support or challenge of quality claims.

Examples:

```text
FOR delivery.on_time >= 0.95
AGAINST delivery.on_time >= 0.95
```

## 9.4 Critical invariant: property != quality

Property:

```text
grade = A
quantity = 10 tons
organic = false
```

Quality:

```text
delivery.on_time = 0.93
product.conformity = 0.97
```

Stake MUST NOT change factual properties.

Stake cannot make:

```text
organic=false
```

become:

```text
organic=true
```

## 9.5 Critical invariant: stake != observed history

Never implement:

```text
quality = quality + stake
```

Correct conceptual model:

```text
Q_observed = evidence-derived observation
S_for      = backing capital
S_against  = challenging capital
Q_effective = participant policy interpretation
```

The protocol does NOT define one universal `Q_effective`.

Each participant policy decides how much backing is sufficient.

## 9.6 Open quality namespace

Do not hard-code every possible quality field into `Obligation`.

Use namespaced keys:

```text
keccak256("delivery.on_time")
keccak256("product.conformity")
keccak256("issuer.default_probability")
```

## 9.7 Quality observation

Conceptual:

```solidity
struct QualityObservation {
    bytes32 qualityKey;
    QualityValueType valueType;
    bytes32 encodedValue;
    uint8 decimals;

    bytes32 sourceType;
    bytes32 evidenceHash;

    uint64 observedAt;
    uint64 validUntil;
    uint32 observationCount;
    uint32 confidencePpm;
}
```

## 9.8 Quality claim

Concept:

```text
obligation #123
qualityKey = delivery.on_time
claim = >= 0.95
validUntil = ...
```

Stake attaches to this claim.

## 9.9 FOR / AGAINST stake

Stake is scoped by:

```text
(obligationId, qualityKey, claimId, stakerPassportId, collateralAsset)
```

Never silently apply stake for one quality to another quality.

Example:

```text
stake on delivery.on_time
```

does not satisfy:

```text
product.conformity
```

## 9.10 Different collateral assets

Do not add together:

```text
1000 USDC + 1 ETH + 10,000 issuer tokens
```

without an explicit valuation rule.

Cross-collateral valuation is not approved MVP logic.

---

# 10. Obligation smart-contract requirements

## 10.1 Core obligation fields

Conceptual schema:

```solidity
struct Obligation {
    uint256 issuerPassportId;
    uint256 beneficiaryPassportId;
    bytes32 externalCounterpartyHash;

    ResourceType resourceType;

    bytes32 resourceCode;
    bytes32 unitCode;
    bytes32 currencyCode;

    uint256 totalQuantity;
    uint256 settledQuantity;
    uint8 decimals;

    uint64 dueDate;

    bytes32 propertiesHash;
    string propertiesURI;

    bytes32 sourceRefHash;
    bytes32 evidenceHash;

    bytes32 metadataHash;
    string metadataURI;

    bytes32 qualitySchemaHash;

    ObligationStatus status;
    uint64 createdAt;
}
```

## 10.2 Derived quantities

```text
outstanding = totalQuantity - settledQuantity
available   = outstanding - activeLockedQuantity
```

Invariant:

```text
settled + locked <= total
```

MUST always hold.

## 10.3 Duplicate prevention

Retries cannot mint duplicate economic claims.

Use `sourceRefHash` and versioned issuance semantics.

## 10.4 Unregistered counterparty

An issuer may publish an obligation before the counterparty joins Orbitas.

Represent with:

```text
beneficiaryPassportId = 0
externalCounterpartyHash != 0
```

Such an obligation:
- is indexable;
- may be visible;
- is NOT executable in P2P clearing that requires that counterparty's consent until bound/onboarded.

## 10.5 Locks

Before settlement:

```text
obligation quantity
  ↓
lock(settlementId)
  ↓
settle OR release
```

Multiple locks may exist only up to available quantity.

## 10.6 Redirect settlement

Path clearing creates a settlement instruction.

It MUST NOT silently transfer/novate the original legal claim.

## 10.7 Off-chain fulfillment

The contract MUST NOT claim that a bank payment, goods delivery or service fulfillment happened merely because an on-chain proposal exists.

Off-chain fulfillment requires the configured confirmation/evidence process.

---

# 11. Indexer

Governed by:

- `TRD-04-obligation-indexer.md`

## 11.1 Purpose

The indexer provides:

- passport reads;
- obligation search;
- incoming/outgoing adjacency;
- Q/S search/projections;
- lock/settlement projection;
- analytics;
- UI queries.

## 11.2 The Graph

The Graph is a preferred event-indexing option where the chosen chain is supported.

However application code MUST depend on an Orbitas abstraction:

```typescript
interface ObligationIndex {
  getPassport(...)
  getObligation(...)
  listObligations(...)
  getIncoming(...)
  getOutgoing(...)
  getSettlement(...)
  getSyncStatus(...)
}
```

Do not make the whole product depend directly on The Graph-specific GraphQL behavior.

## 11.3 Recommended projection stack

MVP-friendly:

```text
contract events
  ↓
The Graph OR RPC event adapter
  ↓
Orbitas Indexer Service
  ↓
PostgreSQL
  ↓
optional text/search backend
```

A dedicated graph database is optional optimization, not mandatory MVP dependency.

## 11.4 Graph semantics

```text
node = passportId
edge = active obligation
direction = issuer/debtor → beneficiary/creditor
edge state = (R,Q,S)
weight = currently available quantity/value in relevant dimension
```

## 11.5 Reorg/finality

Indexer must store chain provenance and distinguish observed vs finalized projection.

Before locking:
- read projection for discovery;
- revalidate canonical contract state.

---

# 12. Clearing engine

Governed by:

- `TRD-05-clearing-path-discovery.md`

## 12.1 Mandatory algorithm

Core algorithm is deterministic path-enabled clearing.

For:

```text
A --x--> B --y--> C
```

for compatible dimensions:

```text
d = min(x,y)
```

propose:

```text
A -----d-----> C
```

and reduce the two source obligations by matched quantity in settlement terms.

## 12.2 No cycle requirement

A path does NOT need:

```text
C → A
```

for clearing discovery.

Therefore:
- bilateral netting is a special case;
- cycles may be reduced through path operations;
- separate cycle optimizer is not a required dependency.

## 12.3 Deterministic ordering

When reproducible tie-break is required, use a stable deterministic policy.

Recommended baseline:

1. eligible intermediary `B`: smallest passport ID;
2. incoming edge: highest available compatible quantity/value;
3. tie → smallest obligation ID;
4. outgoing edge: highest compatible quantity/value;
5. tie → smallest obligation ID.

If a different deterministic rule is implemented, document it as an ADR/TRD change.

## 12.4 Run modes

### DISCOVER_ONE_STEP

Read-only candidate generation.

### SIMULATE_FIXED_POINT

Virtual repeated reductions on a snapshot.

Useful for liquidity scanner and analytics.

### EXECUTE_STEPWISE

Recommended production mode:
- discover;
- policy evaluate;
- revalidate;
- lock;
- settle;
- refresh graph.

## 12.5 Multidimensional clearing eligibility

An edge/path is not executable merely because graph topology exists.

Required conceptual rule:

\[
EligiblePath =
GraphPath
\cap ResourceCompatibility
\cap QualityConstraints
\cap ConsentConstraints
\]

## 12.6 Monetary same currency

Directly comparable.

## 12.7 Different currency

Requires explicit approved conversion/equivalence.

No implicit FX oracle until defined.

## 12.8 Same goods/service type

May be compared when:
- resourceCode compatible;
- unit compatible/normalized deterministically;
- specification compatible;
- policy permits.

## 12.9 Unlike goods/services

Do not automatically convert.

Require explicit acceptance/equivalence or manual quote.

## 12.10 Q/S example

Observed:

```text
delivery.on_time = 0.72
```

Receiver policy:

```text
accept if:
  observed >= 0.80

OR

  observed >= 0.70
  AND approved positive guarantee coverage >= 30%
  AND negative guarantee coverage <= 5%
```

Stake can make the path acceptable because **the policy allows it**.

The observed value remains 0.72.

---

# 13. Consent policies

Consent is participant-owned.

Conceptual evaluation result:

```text
AUTO_ACCEPT
MANUAL_APPROVAL
REJECT
```

Policies may constrain:

- payer/receiver;
- counterparty whitelist/blacklist;
- amount;
- quantity;
- resource type;
- currency;
- due date;
- jurisdiction;
- quality values;
- evidence confidence;
- positive stake;
- negative stake;
- accepted collateral;
- guarantor/staker identity when later enabled.

## 13.1 Required behavior

Agents MUST NOT:
- bypass consent because path economics look attractive;
- let AI override `REJECT`;
- use stale policy after material update;
- sign on behalf of participant without explicit delegated authority.

---

# 14. AI role

AI is optional for MVP correctness.

## 14.1 AI MAY

- rank deterministic candidates;
- explain why a path is useful;
- summarize documents;
- suggest consent policy settings;
- flag anomalies;
- recommend manual review;
- help map natural-language policy intent into a proposed structured policy;
- assist with non-binding negotiation.

## 14.2 AI MUST NOT

- invent obligations;
- invent counterparties;
- invent amounts;
- fabricate evidence;
- create quality observations without identified source;
- bypass consent;
- mutate a deterministic settlement amount;
- determine on-chain finality;
- claim an off-chain payment occurred without deterministic confirmation;
- create an unapproved exchange rate;
- treat LLM confidence as creditworthiness.

## 14.3 AI unavailability

If AI is down:

```text
deterministic clearing must still function
```

This is a release requirement.

---

# 15. P2P meaning

P2P is an economic/protocol property, not a claim that every service must literally run on a user's laptop.

Allowed:
- hosted indexer;
- hosted relayer;
- hosted discovery API;
- managed connector;
- managed monitoring.

Not allowed by default:
- Orbitas becoming principal debtor/creditor;
- central operator owning participant obligations;
- mandatory global custody;
- central service having unilateral power to settle outside participant authorization.

---

# 16. Signatures and keys

## 16.1 Private keys

ERP connectors MUST NOT store participant raw private keys.

## 16.2 Relayed operations

Use typed signed intents where relayer submits on behalf of participant.

Recommended EVM pattern:
- EIP-712 typed data;
- nonce;
- expiry/deadline;
- domain separator including chain ID + contract.

## 16.3 Replay protection

Mandatory for:
- relayed passport registration;
- obligation issuance;
- settlement consent;
- operator actions where signed intents are used.

---

# 17. Participant passport implementation order

Follow:

1. TRD-01 issuance UX/API;
2. TRD-02 registry contract;
3. index passport events;
4. ERP onboarding integration.

Minimum successful path:

```text
companyName
website
wallet
  ↓
metadata hash/URI
  ↓
registerPassport
  ↓
passportId
```

Do not block this flow on KYB.

---

# 18. ERP connector contract

Every connector MUST implement the same conceptual interface.

```typescript
interface OrbitasERPConnector {
  connectTenant(...): Promise<TenantLink>;

  getCompanyProfile(...): Promise<CompanyProfile>;

  listMonetaryObligations(...): Promise<ERPObligation[]>;
  listGoodsObligations(...): Promise<ERPObligation[]>;
  listServiceObligations(...): Promise<ERPObligation[]>;

  mapCounterparty(...): Promise<CounterpartyRef>;

  normalizeObligation(...): Promise<OrbitasObligationDraft>;

  publishObligation(...): Promise<PublishedObligationRef>;

  getSourceVersion(...): Promise<SourceVersion>;

  validateSettlementWriteback(...): Promise<ValidationResult>;
  writebackSettlement(...): Promise<WritebackResult>;

  getSyncStatus(...): Promise<SyncStatus>;
}
```

Exact language/interface can differ, but semantics must remain consistent.

## 18.1 Connector rule

Core Orbitas services MUST operate on Orbitas domain objects.

They MUST NOT import Odoo/QBO/1C SDK models directly into clearing logic.

---

# 19. Odoo connector

Governed by:

- `TRD-06-orbitas-odoo-plugin.md`

## 19.1 Priority

Odoo is the first ERP integration.

## 19.2 Preferred deployment

Odoo addon/module.

Remote integration is possible, but local addon is preferred for:
- semantic access;
- local privacy;
- write-back;
- user UI.

## 19.3 Core source families

Monetary:
- invoices;
- vendor bills;
- residual balances.

Goods:
- purchase/sales commitments;
- delivery residuals where available.

Services:
- service order lines/accepted quantities where available.

## 19.4 Critical write-back rule

Never silently rewrite/delete original invoice history.

Write-back must be:
- auditable;
- idempotent;
- configuration/jurisdiction-aware.

If chain settlement is final but Odoo reconciliation fails:

```text
SETTLED_RECONCILIATION_REQUIRED
```

Do NOT pretend settlement failed.

---

# 20. QuickBooks connector

Governed by:

- `TRD-07-orbitas-quickbooks-plugin.md`

## 20.1 Current assumption

QuickBooks Online.

## 20.2 Integration model

Hosted cloud connector is expected.

Conceptually:
- OAuth connection;
- AR/AP sync;
- change/webhook/poll recovery;
- normalized obligation mapping;
- token publication;
- settlement write-back strategy.

## 20.3 Important constraint

QBO is accounting-centric.

Do not infer a physical goods/service commitment merely from a generic Item without sufficient source data.

---

# 21. 1C:Enterprise connector

Governed by:

- `TRD-08-orbitas-1c-enterprise-plugin.md`

## 21.1 Platform

1C:Enterprise 8.3 family.

## 21.2 Preferred deployment

Configuration extension `.cfe`.

Fallback:
- Standard OData;
- custom HTTP service.

## 21.3 Critical architecture

Do not couple Orbitas core to one 1C configuration.

Use profile abstraction:

```text
I1COrbitasProfile
  getCompanyProfile
  listReceivables
  listPayables
  listGoodsCommitments
  listServiceCommitments
  resolveCounterparty
  getSourceVersion
  prepareSettlementWriteback
  postSettlementWriteback
```

## 21.4 Write-back

Prefer explicit auditable Orbitas settlement object/document in 1C.

Exact accounting movements belong to a certified configuration/jurisdiction strategy.

---

# 22. Evidence model

Evidence is not the same as token state.

## 22.1 Off-chain package

May contain:
- invoice;
- contract;
- order;
- acceptance act;
- shipping/delivery record;
- service evidence;
- quality evidence.

## 22.2 On-chain commitment

Store/reference:
- `evidenceHash`;
- `metadataHash`;
- URI/reference.

Do NOT put full commercially sensitive documents on-chain.

## 22.3 Integrity

When metadata is fetched:
- verify content hash;
- never trust URI content merely because URI is present.

---

# 23. Obligation lifecycle

Conceptual:

```text
ERP_ONLY
   ↓
NORMALIZED
   ↓
PUBLISHED / ACTIVE
   ↓
┌───────────────┬────────────────┐
│               │                │
LOCKED       PARTIAL         CANCELLED residual
│               │
↓               ↓
SETTLED      ACTIVE residual
```

Exact enums belong in TRD/SRS, but user-visible semantics must distinguish:
- available;
- locked;
- partially settled;
- settled;
- cancelled.

---

# 24. Proposal lifecycle

Conceptual:

```text
CANDIDATE
  ↓
POLICY_EVALUATION
  ↓
┌──────────────┬──────────────┐
AUTO_ACCEPT   MANUAL        REJECT
  │              │
  └──────┬───────┘
         ↓
      ACCEPTED
         ↓
      REVALIDATE
         ↓
        LOCK
         ↓
      SETTLING
      /      \
  SETTLED   FAILED
              ↓
        RELEASE LOCKS
```

Accepted proposal is NOT billable.

Successfully settled value is billable.

---

# 25. Billing

Primary billing metric:

```text
Successfully Settled Value
```

Rules:
- candidate proposal → no fee;
- accepted proposal → no settlement fee;
- failed proposal → no settlement fee;
- partial successful settlement → fee only on successful part;
- complete successful settlement → fee on settled value.

Fee percentage is not fixed in this file.

Every billing event must trace to:
- settlementId;
- finalized settlement state;
- settled quantity/value.

---

# 26. Privacy

Agents MUST minimize disclosure.

A participant should not need to expose:
- entire ERP;
- all customers;
- all suppliers;
- all invoices;
- unrelated quality evidence.

Local path discovery is preferred because it can work on local neighborhood data.

Advanced ZKP is outside MVP.

---

# 27. Security invariants

All implementation agents and reviewers MUST preserve these.

## Identity

1. One active controller mapping per passport.
2. Passport cannot be freely transferred as an economic asset.
3. Connector operator authority is scoped.

## Obligation

4. `settled + locked <= total`.
5. Same source version is not minted twice because of retry.
6. Cancel cannot erase settled history.
7. Arbitrary transfer is disabled in MVP.

## Multidimensional token

8. Stake cannot change factual properties.
9. Stake cannot mutate observed quality history.
10. Stake is scoped to explicit claim/dimension.
11. Different collateral assets are not blindly summed.
12. A claim about one quality cannot satisfy another quality.

## Settlement

13. Locked amount cannot be settled twice.
14. A settlement cannot consume more than its locks.
15. Failed settlement releases only non-finalized locks.
16. Indexer projection is not sufficient authorization.

## AI

17. AI cannot create canonical financial state.
18. AI cannot bypass policy.
19. AI outage does not stop deterministic clearing.

## ERP

20. Chain finality and ERP reconciliation status are separate.
21. Failed ERP write-back must be visible.
22. Retry does not create duplicate postings.

---

# 28. Idempotency rules

All write APIs need an idempotency strategy.

Recommended ERP publication key:

```text
hash(
  connectorType |
  tenantId |
  sourceRecordType |
  sourceRecordId |
  sourceVersion |
  action
)
```

Recommended event identity:

```text
(chainId, txHash, logIndex)
```

Recommended settlement uniqueness:

```text
settlementId
```

Do not use random retry-generated IDs where the business action must be recognized as the same action.

---

# 29. Observability baseline

Every subsystem must emit enough information to answer:

- what source ERP record created this obligation?
- which passport issued it?
- which token/contract represents it?
- which evidence hash backs it?
- what Q/S state was used during proposal evaluation?
- which policy allowed/rejected it?
- which source obligations created a settlement?
- what was locked?
- what finalized?
- what failed?
- what was written back?
- what became billable?

Required correlation fields should include when applicable:

```text
requestId
tenantId
passportId
obligationId
claimId
proposalId
settlementId
txHash
sourceRefHash
```

Never log raw private keys.

Avoid logging full private commercial documents.

---

# 30. Testing strategy

No core component is complete with only happy-path tests.

## 30.1 Contract tests

Required:
- permissionless passport registration;
- duplicate controller rejection;
- controller rotation;
- operator permissions;
- obligation issuance;
- duplicate source rejection;
- partial locks;
- concurrent locks;
- lock release;
- partial settlement;
- full settlement;
- arbitrary transfer rejection;
- unregistered counterparty behavior;
- signature replay;
- invariant fuzzing;
- Q observation behavior;
- FOR/AGAINST claim scope;
- stake does not mutate observed Q.

## 30.2 Indexer tests

Required:
- deterministic replay;
- duplicate event handling;
- reorg rollback;
- active quantity projection;
- Q/S projection;
- different collateral separation;
- stale-index state.

## 30.3 Clearing tests

Required:
- acyclic A→B→C;
- no cycle dependency;
- bilateral special case;
- path in cycle;
- deterministic tie-break;
- partial quantity;
- currency incompatibility;
- goods compatibility;
- unlike resource rejection without equivalence;
- quality constraint;
- positive stake allowed by policy;
- negative stake blocking;
- stale state before lock;
- lock conflict;
- AI disabled.

## 30.4 Connector tests

For every ERP:
- initial sync;
- incremental sync;
- source version changes;
- retry/idempotency;
- unregistered counterparty;
- tokenization;
- settlement write-back;
- partial write-back;
- final chain settlement + failed ERP reconciliation;
- auth/permission failure.

---

# 31. Definition of done

A feature is done only when:

1. it matches this file and the governing TRD;
2. public interfaces are documented;
3. business state transitions are deterministic;
4. required negative tests exist;
5. retries are idempotent;
6. audit identifiers propagate end-to-end;
7. privacy boundaries are respected;
8. canonical-state boundaries are respected;
9. AI cannot bypass deterministic rules;
10. no out-of-MVP feature was added implicitly;
11. documentation is updated if interface/domain behavior changed.

For settlement-related work add:

12. double-settlement test exists;
13. partial settlement test exists;
14. failure/release behavior test exists;
15. ERP reconciliation failure is tested.

---

# 32. AI agent roles

Agents may have different names in the implementation environment; behavior should follow these responsibilities.

## 32.1 Planner / Architect agent

Must:
- read `AGENTS.md`;
- read governing PRD/TRD;
- list affected contracts/APIs/data models;
- identify open decisions;
- avoid implementing an open decision as fact;
- produce a scoped implementation plan;
- identify migrations and backward compatibility.

Must not:
- broaden scope to future Resourceconomy;
- replace path clearing with cycle-only design;
- make indexer canonical.

## 32.2 Builder agent

Must:
- implement only approved scoped behavior;
- preserve invariants;
- create/update tests;
- keep adapters separate from core domain;
- use deterministic financial arithmetic;
- propagate idempotency/correlation IDs.

Must stop and flag when:
- legal/product semantics are missing;
- staking economics would put real collateral at risk;
- resource equivalence is undefined;
- ERP write-back accounting treatment is undefined.

## 32.3 Reviewer agent

Must check:
- product alignment;
- invariant preservation;
- authorization;
- idempotency;
- double settlement;
- state source;
- rounding/fixed-point;
- reorg/finality;
- ERP failure recovery;
- AI non-authority.

Reviewer must reject code where:
- LLM output determines settlement quantity;
- index DB is trusted instead of contract state for final action;
- duplicate retries can mint claims;
- observed Q can be increased by stake;
- source documents are put directly on-chain without explicit need.

## 32.4 Test / QA agent

Must derive tests from:
- this file;
- PRD acceptance criteria;
- TRD acceptance criteria;
- protocol invariants.

QA should prioritize:
- economic correctness;
- negative paths;
- retry behavior;
- race conditions;
- stale state;
- connector recovery.

## 32.5 Release agent

Before release verify:
- migrations applied;
- deployed contract addresses/ABIs match indexer;
- start blocks configured;
- chain ID correct;
- index synchronized;
- connector secrets configured;
- ERP permissions least-privilege;
- observability active;
- rollback/reconciliation runbook exists;
- no unresolved P0/P1 settlement integrity issue.

---

# 33. Implementation sequence

Default implementation order:

## Phase 1 — Identity

1. Passport profile schema
2. Passport issuance API/UI
3. Passport registry contract
4. Passport index projection

## Phase 2 — Obligation protocol

5. Universal obligation schema
6. Obligation registry/token
7. Evidence commitments
8. SourceRef duplicate prevention
9. Locks
10. Settlement instruction state

## Phase 3 — Multidimensional Q/S

11. `propertiesHash/propertiesURI`
12. quality namespace/schema
13. quality observations
14. quality claims
15. stake/guarantee interface
16. index Q/S projections

Real collateral economics may remain disabled until dedicated TRD.

## Phase 4 — Index

17. contract event indexing
18. PostgreSQL projection
19. adjacency query interface
20. sync/finality monitoring

## Phase 5 — Clearing

21. deterministic local path discovery
22. resource compatibility
23. Q/S policy constraints
24. consent policy evaluation
25. proposal model
26. revalidation
27. lock/settlement orchestration

## Phase 6 — Odoo

28. connector/module
29. source mappings
30. passport onboarding
31. token publication
32. clearing UI
33. write-back strategy
34. reconciliation exceptions

## Phase 7 — QuickBooks Online

35. OAuth/tenant integration
36. AR/AP sync
37. token publication
38. proposal/settlement integration
39. write-back strategy

## Phase 8 — 1C

40. choose certified configuration
41. extension/profile layer
42. source mapping
43. token publication
44. proposal UI
45. settlement artifact/write-back

---

# 34. Explicit out-of-MVP list

Do NOT add unless explicitly requested:

- full KYB/passport verification;
- universal reputation score;
- mandatory credit scoring;
- RWA issuance;
- factoring marketplace;
- lending;
- investor marketplace;
- public AMM;
- public DEX;
- free transfer/assignment of obligations;
- freelancer passport;
- Learn2Earn;
- SocialFi;
- housing/rental product;
- consumer IOUs;
- game guild product;
- DAO/Soprocvetanie governance;
- DisPOS as mandatory infrastructure;
- custom global Orbitas blockchain;
- advanced ZKP;
- full DID/VC stack;
- automatic legal novation;
- global cross-resource market price;
- AI-determined economic finality.

---

# 35. Architecture guardrails

Agents MUST NOT:

1. build a central clearing house merely for convenience;
2. require a global full obligation graph;
3. make cycle discovery a prerequisite for clearing;
4. create one contract per invoice;
5. use one scalar reputation score as replacement for `Q/S`;
6. allow stake to purchase historical quality;
7. make full documents public/on-chain;
8. bind core clearing logic to Odoo/QBO/1C SDK models;
9. let connector retries duplicate tokens;
10. let ERP reconciliation failure rewrite finalized chain state;
11. add arbitrary token transfer before legal/product approval;
12. hide unresolved open decisions inside code defaults.

---

# 36. Change-control rule

When changing any of the following:

- passport semantics;
- obligation token semantics;
- sourceRef identity;
- Q/S schema;
- lock rules;
- settlement finality;
- consent evaluation;
- resource equivalence;
- ERP write-back semantics;
- billing semantics;

the agent MUST:

1. identify governing decision/TRD;
2. state the proposed behavior change;
3. describe backwards compatibility impact;
4. update tests;
5. update corresponding TRD/SRS;
6. create ADR if architectural;
7. update `AGENTS.md` if project-wide behavior changes.

Do not change protocol events casually after deployed production usage begins.

---

# 37. Minimal domain contracts

These are conceptual, not language-binding.

## Participant

```typescript
type Participant = {
  passportId: bigint
  controller: Address
  metadataHash: Hash
  metadataURI: URI
  status: "ACTIVE" | "DEACTIVATED"
  verificationLevel: "SELF_DECLARED"
}
```

## Obligation

```typescript
type Obligation = {
  obligationId: bigint

  issuerPassportId: bigint
  beneficiaryPassportId?: bigint
  externalCounterpartyHash?: Hash

  resourceType: "MONETARY" | "GOODS" | "SERVICE"

  resourceCode: string
  unitCode: string
  currencyCode?: string

  totalQuantity: bigint
  settledQuantity: bigint
  decimals: number

  dueDate: number

  propertiesHash: Hash
  propertiesURI: URI

  sourceRefHash: Hash
  evidenceHash: Hash

  metadataHash: Hash
  metadataURI: URI

  qualitySchemaHash: Hash

  status: ObligationStatus
}
```

## Quality

```typescript
type QualityObservation = {
  obligationId: bigint
  qualityKey: Hash
  encodedValue: Hash
  decimals: number
  sourceType: Hash
  evidenceHash: Hash
  observedAt: number
  validUntil?: number
  confidencePpm: number
}
```

## Quality claim

```typescript
type QualityClaim = {
  claimId: Hash
  obligationId: bigint
  qualityKey: Hash
  operator: "EQ" | "NE" | "GT" | "GTE" | "LT" | "LTE"
  threshold: bigint
  decimals: number
  contextHash?: Hash
  validUntil?: number
}
```

## Stake

```typescript
type QualityStake = {
  claimId: Hash
  stakerPassportId: bigint
  collateralToken: Address
  amount: bigint
  side: "FOR" | "AGAINST"
  lockedUntil?: number
}
```

## Proposal

```typescript
type ClearingProposal = {
  proposalId: Hash
  snapshotBlock: bigint
  steps: ClearingStep[]
  policyDecisions: PolicyDecision[]
  residuals: Residual[]
  status: ProposalStatus
}
```

## Settlement

```typescript
type Settlement = {
  settlementId: Hash
  proposalId: Hash
  sourceObligations: SourceSettlement[]
  payerPassportId: bigint
  receiverPassportId: bigint
  quantity: bigint
  decimals: number
  resourceCode: string
  consentProofHash: Hash
  status: SettlementStatus
}
```

---

# 38. Short context block for constrained agents

If an AI agent can only read one small section, preserve this:

> **Orbitas MVP is an Odoo-first P2P clearing network for ERP-backed tokenized business obligations. Participants self-register a company passport using company data, website and wallet; no admin/KYB approval is required in MVP. Every published monetary/goods/service obligation gets an on-chain representation linked to off-chain/IPFS evidence. An obligation is multidimensional: `T=(R,Q,S)` where `R` is resource/properties, `Q` is evidence-derived quality, and `S` is attribute-specific FOR/AGAINST stake/guarantee. Stake never rewrites factual properties or observed quality history. A deterministic path-enabled clearing engine discovers open paths such as `A→B→C`, evaluates resource compatibility plus Q/S and participant consent policies, revalidates canonical contract state, locks source obligations, executes redirect payment/fulfillment without automatic novation, finalizes P2P settlement, and reconciles the result back into ERP. Indexers/The Graph are read projections only. AI is optional and advisory; it cannot define settlement amounts or finality. Billing occurs only on Successfully Settled Value. RWA, factoring, public DEX/AMM, universal credit scoring, DisPOS, advanced ZKP and unrelated Resourceconomy verticals are out of MVP.**

---

# 39. Final decision rule for agents

When choosing between multiple implementations, prefer the design that maximizes, in this order:

1. settlement correctness;
2. participant control/consent;
3. prevention of double use;
4. deterministic auditability;
5. ERP source integrity;
6. P2P economic structure;
7. minimum disclosure;
8. adapter independence;
9. multidimensional obligation extensibility;
10. smallest viable MVP scope.

If a proposed shortcut conflicts with one of these, flag it rather than silently implementing it.
