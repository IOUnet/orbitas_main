# TRD-06 — Orbitas ↔ Odoo Plugin

**Status:** Draft for approval  
**Depends on:** TRD-01..05  
**Priority:** first ERP connector  
**Target:** Odoo 19 direction; compatibility profile should be versioned

## 1. Objective

Integrate Orbitas into Odoo without replacing Odoo accounting.

The plugin must:
- onboard the company/passport;
- discover supported obligations;
- normalize them to Orbitas domain objects;
- publish selected obligations on-chain;
- show clearing proposals;
- capture consent;
- receive settlement results;
- write settlement/reconciliation state back to Odoo.

Odoo remains canonical for original accounting records.

## 2. Recommended deployment

Primary mode:

**Odoo addon `orbitas_connector` installed in the Odoo instance.**

Advantages:
- direct ORM access;
- local data minimization;
- local UI;
- outbound communication to participant Orbitas node;
- easier atomic business methods for write-back.

Optional remote integration:
- Odoo 19 External JSON-2 API through `/json/2` where available;
- useful for hosted connector mode.

Do not build new work around deprecated XML-RPC/JSON-RPC unless supporting older Odoo versions explicitly.

## 3. Odoo module structure

Recommended MVP addon:

```text
orbitas_connector/
  __manifest__.py
  models/
    orbitas_settings.py
    orbitas_obligation_link.py
    orbitas_settlement.py
    orbitas_sync_state.py
  services/
    passport_service.py
    obligation_mapper.py
    orbitas_api.py
    settlement_service.py
  views/
    settings.xml
    obligations.xml
    proposals.xml
    settlements.xml
  data/
    cron.xml
    security.xml
```

Earlier project discussions had separate `orbita_catalog`, `orbita_publication`, `orbita_obligation_catalog`, etc. For MVP these should be consolidated unless module separation is technically necessary.

## 4. Local Orbitas models

### `orbitas.obligation.link`

Fields:
- Orbitas obligation ID
- source model
- source record ID
- source record version/write date
- sourceRefHash
- token contract/chain
- publish status
- token status
- last sync
- error state

### `orbitas.settlement`

Fields:
- settlementId
- proposalId
- affected source records
- settled quantities
- finality status
- accounting write-back status
- transaction/evidence reference
- error/retry state

### `orbitas.sync.state`

Per data class:
- cursor/watermark
- last successful sync
- last failure
- retry state

## 5. Source mappings

Exact Odoo fields vary by localization/modules. Use semantic adapters.

### Monetary receivables/payables

Primary source family:
- `account.move` customer invoices / vendor bills
- residual open amount
- partner
- currency
- invoice/bill date
- due date/payment terms
- payment/reconciliation status
- credit notes affecting residual

Only outstanding economic amount may be published.

### Goods commitments

Potential sources:
- sales orders/order lines;
- purchase orders/order lines;
- delivery/receipt state;
- stock move/picking evidence where required.

### Service commitments

Potential sources:
- sales/purchase order lines for service products;
- service quantity/unit;
- delivered/accepted quantity where available.

The mapper MUST produce the shared Orbitas obligation model, not leak Odoo model names into core clearing logic.

## 6. Counterparty mapping

Map Odoo `res.partner` to:
- existing `passportId`, when linked;
- otherwise deterministic `externalCounterpartyHash`.

A local mapping table must store:

```text
Odoo partner ID ↔ passportId / externalCounterpartyHash
```

Unregistered counterparties can be tokenized according to TRD-03 but are not executable path participants until onboarded.

## 7. Company/passport onboarding

Plugin Settings flow:

1. Show current Odoo company.
2. Ask for company website/name, prefill from Odoo when available.
3. User edits/accepts.
4. Connect wallet/controller.
5. Execute TRD-01 self-registration.
6. Persist `passportId` and controller address.

No administrator/KYB approval in MVP.

## 8. Publication workflow

1. User/system selects source obligation.
2. Mapper computes normalized data.
3. Build evidence package/metadata.
4. Persist evidence off-chain/IPFS.
5. Compute `sourceRefHash`.
6. Prepare signed issuance intent.
7. Submit to TRD-03.
8. Wait for finality/index.
9. Save `obligationId`.
10. Show tokenized state in Odoo.

Retry MUST be idempotent and never mint duplicate claim.

## 9. Sync strategy

### Initial sync

Read supported open obligations.

### Incremental sync

Primary addon mode:
- hook relevant model changes where safe;
- enqueue async outbound sync;
- periodic reconciliation cron as safety net.

Remote JSON-2 mode:
- polling by `write_date`/domain query;
- periodic full consistency scan.

Every sync item carries:
- source ID;
- source version/write timestamp;
- idempotency key.

## 10. Odoo API considerations

For remote Odoo 19:
- prefer JSON-2;
- authenticate using dedicated API key/bot user;
- use least privilege;
- avoid multi-call "transactions" for payment/reservation-style operations.

Where write-back requires several Odoo changes to be atomic, implement one server-side addon method that performs them in one Odoo database transaction.

## 11. Clearing UX

Menus:

```text
Orbitas
 ├─ Dashboard
 ├─ Obligations
 ├─ Clearing Opportunities
 ├─ Approvals
 ├─ Settlements
 └─ Settings
```

Opportunity card:
- obligations involved;
- before/after;
- cash/resource relief;
- counterparty changes;
- policy result;
- approve/reject when manual.

## 12. Consent

Default company consent policy is managed through Orbitas but editable from Odoo.

Plugin MUST NOT auto-approve outside active policy.

For policy changes with material impact, require authorized user confirmation.

## 13. Settlement write-back

Critical rule:
**do not rewrite or delete original invoice/order history.**

On successful Orbitas settlement:
1. create/update local `orbitas.settlement`;
2. validate source records still correspond to settlement;
3. execute jurisdiction/configuration-specific accounting operation;
4. reconcile affected residuals where appropriate;
5. attach Orbitas settlement ID and evidence reference;
6. record audit result.

Recommended implementation boundary:

```python
class SettlementWritebackStrategy:
    def validate(...)
    def prepare(...)
    def post(...)
    def reconcile(...)
    def audit(...)
```

Exact debit/credit/accounting entries are NOT hard-coded in this TRD because redirect-payment treatment depends on jurisdiction/localization.

The pilot must implement one approved strategy.

## 14. Reconciliation failure

If on-chain settlement is final but Odoo write-back fails:
- status = `SETTLED_RECONCILIATION_REQUIRED`;
- do not attempt to reverse chain finality automatically;
- retry idempotently;
- show exception to accountant.

## 15. Security

- dedicated Orbitas/Odoo integration user where remote API is used;
- minimum model permissions;
- secrets in Odoo secure configuration/system parameters or external secret store;
- wallet private key never stored in Odoo plugin;
- signed intents delegated to wallet/approved signer;
- outbound HTTPS only;
- verify Orbitas webhook signatures;
- prevent SSRF via arbitrary gateway URLs;
- audit all write-back actions.

## 16. Observability

Metrics:
- source obligations discovered;
- tokenization success;
- duplicate prevented;
- sync lag;
- proposal count;
- settlement count/value;
- write-back success/failure;
- queue backlog;
- API latency.

## 17. Tests

- Odoo customer invoice → monetary obligation;
- vendor bill mapping;
- partial residual;
- credit note/residual change;
- goods order mapping;
- service line mapping;
- unregistered partner hash;
- self-service passport;
- idempotent publish retry;
- stale source before settlement;
- successful write-back;
- partial write-back;
- final settlement + write-back failure recovery;
- permission/record rule restrictions.

## 18. Acceptance criteria

- A company can install/configure plugin and create passport.
- Open Odoo obligations can be published without manual re-entry.
- Each published source record maps to one canonical on-chain obligation.
- Clearing proposals are visible in Odoo.
- Successful settlement is reflected through an auditable Odoo write-back strategy.
- Core Orbitas domain logic has no dependency on Odoo-specific classes.
