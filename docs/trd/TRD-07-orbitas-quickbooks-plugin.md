# TRD-07 — Orbitas ↔ QuickBooks Connector

**Status:** Draft for approval  
**Depends on:** TRD-01..05  
**Target assumption:** QuickBooks Online (QBO) for MVP connector  
**Note:** QuickBooks Desktop/Web Connector is a separate integration profile unless explicitly added

## 1. Objective

Provide an Orbitas connector for QuickBooks Online using the same normalized Orbitas domain model as Odoo.

The connector must:
- authorize a QBO company;
- create/link Orbitas participant passport;
- ingest supported AR/AP and selected goods/service commitments;
- tokenize published obligations;
- receive proposals/settlements;
- write reconciliation/accounting references back to QBO using an approved strategy.

## 2. Architecture

Recommended hosted connector:

```text
QuickBooks Online
      │ OAuth 2.0 / Accounting API
      │ Webhooks + CDC/poll fallback
      ▼
Orbitas QBO Connector
      ├─ tenant/token vault
      ├─ entity mapper
      ├─ obligation mapper
      ├─ sync engine
      └─ write-back adapter
      │
      ▼
Participant Orbitas Node / Protocol
```

Unlike Odoo, QBO normally uses a cloud connector rather than an installed server-side module.

## 3. Tenant identity

Persist:
- Orbitas tenant ID;
- Intuit `realmId` / company identifier;
- access token metadata;
- encrypted refresh token;
- token expiry;
- linked `passportId`;
- sync cursor;
- environment (sandbox/production).

OAuth credentials MUST be encrypted at rest.

## 4. Source object mappings

Exact QBO entity availability must be verified in sandbox for the target locale/account tier.

### Monetary receivables

Primary:
- Invoice
- open balance / linked payments/credits
- Customer
- Currency where multi-currency is enabled
- due date

### Monetary payables

Primary:
- Bill
- open balance / linked bill payments/credits
- Vendor
- currency
- due date

### Goods/services

Potential sources:
- Item
- PurchaseOrder
- Invoice/Sales transactions carrying item/service lines
- other supported purchasing/sales objects depending on QBO plan/locale.

The connector MUST map to Orbitas semantic obligation types and MUST NOT assume every QBO company exposes identical transaction types.

## 5. Passport onboarding

After OAuth:
1. read company display/profile information available from QBO;
2. prefill company name;
3. user enters/confirms website;
4. user connects controller wallet;
5. invoke TRD-01;
6. store `passportId` against `realmId`.

No Intuit connection itself is treated as KYB.

## 6. Sync model

Use a combination of:
- initial query/backfill;
- QBO webhooks for change notification;
- Change Data Capture where supported;
- periodic reconciliation poll to recover missed events.

Webhook notification is a trigger, not canonical business content. After notification, re-read the current source object before updating Orbitas projection.

## 7. Idempotency

Source identity:

```text
QBO | realmId | entityType | entityId | SyncToken/version
```

Generate sourceRefHash from normalized source identity.

QBO retry/webhook duplication must not mint duplicate obligations.

## 8. Publication

Same protocol as TRD-06:
1. map source transaction to Orbitas obligation;
2. build off-chain evidence metadata;
3. compute sourceRefHash/evidenceHash;
4. participant signs issuance intent;
5. submit TRD-03;
6. persist `obligationId`.

Connector must re-evaluate QBO open balance before publication if data is stale.

## 9. Counterparty mapping

Customer/Vendor mappings store:
- QBO entity ID;
- display name;
- optional email/domain;
- Orbitas `passportId` if linked;
- otherwise externalCounterpartyHash.

Do not use a display name as unique identity.

## 10. Goods/service semantics

QBO is primarily accounting-oriented; resource commitments may be less complete than in a full ERP.

Therefore:
- only publish goods/service obligations when required quantity/unit/due/acceptance data is available or explicitly completed by user;
- label evidence source;
- do not infer physical delivery obligation from a generic accounting item alone.

## 11. Settlement write-back strategy

Product requirement:
- preserve original source transaction;
- record Orbitas settlement reference;
- reduce/reconcile outstanding balances only through an accounting-valid QBO transaction.

Define pluggable:

```typescript
interface QboSettlementWritebackStrategy {
  validate(settlement, sourceObjects)
  createAccountingTransaction(...)
  linkOrbitasReference(...)
  verifyResult(...)
}
```

Candidate QBO mechanisms may include payment/bill-payment/journal-entry style records depending on the legal/accounting scenario.

The exact mechanism MUST be selected and tested with an accountant for the pilot; this TRD does not silently prescribe one universal journal entry.

## 12. Failure behavior

### OAuth token expired/revoked
- tenant status `REAUTH_REQUIRED`;
- no destructive write operations;
- existing chain obligations remain valid.

### Webhook delayed/missed
- CDC/poll reconciliation repairs.

### Chain settlement final but QBO write-back fails
- `SETTLED_RECONCILIATION_REQUIRED`;
- retry safely;
- no duplicate accounting transaction.

## 13. Rate limits and retries

Implementation MUST:
- centralize API retry policy;
- honor provider throttling/retry headers;
- exponential backoff with jitter;
- bounded retries for non-idempotent writes;
- use idempotency/correlation metadata around write-back.

Do not encode a hard provider rate limit in domain logic.

## 14. Security

- OAuth 2.0 authorization code flow as required by Intuit;
- encrypt refresh tokens;
- strict redirect URI;
- CSRF state validation;
- rotate/revoke tokens on disconnect;
- minimum scopes;
- verify webhook authenticity according to current Intuit requirements;
- never expose Intuit tokens to browser after backend exchange.

## 15. Observability

Per realm:
- auth health;
- sync cursor/lag;
- webhook receipt;
- API errors;
- source-to-token mapping;
- proposal/settlement status;
- reconciliation exceptions.

## 16. Tests

Use Intuit sandbox.

Required:
- OAuth connect/disconnect;
- initial invoice sync;
- bill sync;
- partial balance change;
- webhook duplicate;
- webhook + stale object re-read;
- CDC/poll recovery;
- passport prefill + website;
- tokenization retry;
- unregistered customer/vendor;
- settlement write-back fixture;
- reconciliation failure retry;
- token revocation.

## 17. Acceptance criteria

- QBO company can connect through OAuth and create/link Orbitas passport.
- Supported open AR/AP can map into exactly the same Orbitas obligation schema used by Odoo.
- Duplicate webhooks/retries do not duplicate on-chain obligations.
- Settlement result can be written back using a pilot-approved accounting strategy.
- No QBO-specific object is required by TRD-05 clearing engine.

## 18. Open question

Confirm product target:
- QuickBooks Online only for first QuickBooks release; or
- also QuickBooks Desktop through Web Connector.

This TRD assumes **QuickBooks Online**.
