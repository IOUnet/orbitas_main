# TRD-08 — Orbitas ↔ 1C:Enterprise Connector

**Status:** Draft for approval  
**Depends on:** TRD-01..05  
**Target:** 1C:Enterprise 8.3 family  
**Architecture principle:** configuration-independent semantic adapter with configuration profiles

## 1. Objective

Integrate Orbitas with 1C:Enterprise without hard-coding the clearing protocol to one Russian/CIS configuration.

1C configurations differ substantially (`Бухгалтерия`, `Управление торговлей`, `ERP`, localized and custom configurations).

Therefore the connector must separate:
- 1C transport;
- configuration-specific mapping;
- Orbitas domain model.

## 2. Preferred deployment modes

### Mode A — 1C configuration extension (`.cfe`) — preferred

Install an Orbitas extension that:
- reads local 1C objects/registers;
- exposes Orbitas UI/settings;
- performs background synchronization;
- calls Orbitas node through HTTP(S);
- creates local settlement/write-back documents.

Advantages:
- local access to configuration semantics;
- no requirement to publish broad OData externally;
- can package configuration-specific mapping profiles.

### Mode B — external connector via Standard OData

Use published 1C Standard OData interface for:
- read/change supported application objects;
- metadata discovery;
- integration where extension installation is undesirable.

### Mode C — custom HTTP service

An Orbitas extension may expose a narrow custom HTTP service for controlled integration.

MVP should implement A first and use B as an interoperability fallback.

## 3. 1C extension structure

Conceptual:

```text
Orbitas Extension
 ├─ Common Modules
 │   ├─ OrbitasClient
 │   ├─ OrbitasMapping
 │   ├─ OrbitasSync
 │   └─ OrbitasSettlement
 ├─ Information Registers
 │   ├─ OrbitasObjectLinks
 │   ├─ OrbitasSyncState
 │   └─ OrbitasSettings
 ├─ Document
 │   └─ OrbitasClearingSettlement
 ├─ Scheduled/Background Jobs
 └─ Managed Forms / Commands
```

Actual metadata object names should follow 1C coding/localization standards.

## 4. Configuration profile abstraction

```text
I1COrbitasProfile
  getCompanyProfile()
  listReceivables()
  listPayables()
  listGoodsCommitments()
  listServiceCommitments()
  resolveCounterparty()
  getSourceVersion()
  prepareSettlementWriteback()
  postSettlementWriteback()
```

Profiles:
- `AccountingProfile`
- `TradeManagementProfile`
- `ERPProfile`
- custom profile extension

TRD-05 never sees these profiles.

## 5. Source data model

Because 1C configurations vary, map by semantic role.

### Monetary obligations

Need:
- debtor;
- creditor;
- document/reference;
- amount outstanding;
- currency;
- due date/payment terms;
- settlement status.

Possible sources include documents plus accounting/accumulation registers; exact profile chooses canonical calculation.

### Goods obligations

Need:
- counterparty;
- nomenclature/item;
- quantity;
- unit;
- delivery date;
- warehouse/location if relevant;
- source order/contract;
- delivered/residual quantity.

### Service obligations

Need:
- service/nomenclature;
- quantity or scope;
- unit;
- due/period;
- counterparty;
- source order/contract/act.

## 6. Standard OData considerations

1C Standard OData can expose catalogs, documents and registers through HTTP and supports read/write operations.

Requirements:
- publish only required objects when using external OData;
- use a dedicated role for remote OData access;
- avoid exposing the entire infobase;
- use metadata discovery to validate profile compatibility.

The connector must not depend on OData for operations that require configuration-specific atomic business logic; custom extension methods/HTTP service are preferred for those.

## 7. Passport onboarding

Extension reads/prefills:
- company name;
- optional registration/tax fields;
- website if available.

User must at minimum confirm:
- company name;
- website.

Then:
- connect controller wallet;
- call TRD-01;
- persist `passportId` in OrbitasSettings.

No admin/KYB approval.

## 8. Source identity and idempotency

1C source identity should use stable reference/GUID where possible:

```text
1C | infobaseId | configurationProfile | metadataType | objectRef | sourceVersion
```

`sourceRefHash` is generated from canonical serialization.

Repeated scheduled jobs MUST NOT create duplicate on-chain obligations.

## 9. Synchronization

### Initial

- identify supported open obligations through profile;
- create local link records;
- let authorized user/policy publish.

### Incremental

Preferred:
- record changes in extension hooks/subscriptions when safe;
- background job batches outbound synchronization;
- periodic full reconciliation.

For OData mode:
- use filtered incremental queries where possible;
- maintain watermark/version;
- periodic consistency scan.

## 10. Background jobs

1C background/scheduled jobs should:
- not block interactive user session;
- batch outbound calls;
- retry transient network errors;
- persist error state;
- be idempotent.

No wallet private key inside background job.

Transactions requiring user signature generate a pending intent for external wallet signing or approved signing agent.

## 11. Counterparty mapping

Maintain information register:

```text
1C counterparty reference
 ↔ Orbitas passportId
 ↔ externalCounterpartyHash
```

A counterparty without passport:
- may appear in tokenized obligation as external hash;
- cannot participate in executable P2P path until linked/onboarded.

## 12. Publication

1. Configuration profile emits normalized obligation.
2. Evidence package generated.
3. Evidence persisted off-chain/IPFS.
4. sourceRefHash generated.
5. signed issuance intent created.
6. TRD-03 issued.
7. local register saves obligationId/token status.

## 13. Clearing UI

Recommended managed forms:
- Orbitas dashboard;
- obligations for publication;
- clearing opportunities;
- approvals;
- settlements;
- reconciliation exceptions;
- connector settings.

UI should use 1C conventions and avoid blockchain jargon in primary flow.

## 14. Settlement write-back

Create an explicit Orbitas settlement artifact in 1C rather than mutate source documents invisibly.

Recommended:
`Document.OrbitasClearingSettlement`

Contains:
- settlementId;
- source object refs;
- settled quantities/amounts;
- counterparties;
- evidence/tx references;
- posting status;
- error state.

Configuration profile determines movements/postings.

Rules:
- original invoice/order/contract remains traceable;
- partial settlement preserves residual;
- posting is idempotent;
- a final on-chain settlement cannot be silently discarded because 1C posting failed;
- failed posting creates reconciliation exception.

## 15. Accounting configuration

Exact postings depend on:
- target 1C configuration;
- accounting standards;
- jurisdiction;
- redirect-payment legal treatment.

Therefore each supported profile must ship a tested `SettlementWritebackStrategy`.

Do not hard-code one chart-of-accounts mapping globally.

## 16. Security

- dedicated 1C role `OrbitasIntegration`;
- least privilege;
- if OData is exposed, restrict published objects and HTTPS endpoint;
- secrets not stored in plain text;
- no private wallet keys;
- validate Orbitas server certificate;
- sign/verify webhook/HTTP messages;
- audit all settlement posting operations.

## 17. Observability

Local:
- information register with sync errors;
- last successful job;
- source/object link state;
- settlement posting errors.

Central/participant node:
- connector health;
- infobase/profile version;
- sync lag;
- API latency;
- tokenization failures;
- reconciliation exceptions.

## 18. Compatibility testing

At minimum define certified profiles for concrete configurations.

For each:
- metadata compatibility check;
- source mapping fixture;
- monetary obligation;
- partial settlement;
- goods/service mapping if supported;
- posting/write-back fixture.

Custom configurations must fail explicitly as `UNSUPPORTED_PROFILE` rather than silently map wrong data.

## 19. Tests

- extension install/uninstall;
- role permissions;
- company/passport onboarding;
- receivable/payable mapping;
- stable sourceRefHash;
- scheduled sync idempotency;
- OData profile fallback;
- unregistered counterparty;
- publication retry;
- settlement document creation;
- partial write-back;
- posting failure recovery;
- unsupported config detection.

## 20. Acceptance criteria

- A supported 1C infobase can create/link passport.
- Supported obligations map to the same Orbitas schema as Odoo/QBO.
- Background sync is idempotent.
- Published obligation gets one on-chain obligationId.
- Settlement is represented by an explicit auditable 1C artifact.
- Configuration-specific posting logic is isolated from Orbitas clearing core.

## 21. Open questions

Before implementation planning, choose first certified 1C configuration(s), for example:
- 1C:ERP;
- 1C:Accounting/Бухгалтерия;
- 1C:Trade Management/Управление торговлей.

The platform-level TRD remains valid across profiles.
