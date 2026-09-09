# Orbitas — Product Requirements Document (PRD)

**Version:** 0.9 Draft for Approval  
**Date:** 2026-09-01  
**Status:** Review / Approval Required  
**Product:** Orbitas MVP — P2P Clearing Network for ERP-Backed Tokenized Business Obligations  
**Primary ERP:** Odoo  
**Next ERP targets:** QuickBooks, 1C, other accounting/ERP systems  
**Business source of truth:** `AGENTS.md` / approved BRD decisions  

---

# 1. Change History

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-09-01 | Initial PRD structure |
| 0.9 | 2026-09-01 | Consolidated MVP PRD aligned with approved Orbitas BRD / AGENTS.md |

---

# 2. Overview / Product Context

Orbitas is a P2P clearing network for small and medium businesses.

The product connects to existing accounting/ERP systems, extracts business obligations, creates an on-chain token representation for each clearing-eligible obligation, links it to documentary evidence stored off-chain/IPFS, discovers path-enabled clearing opportunities, evaluates them against machine-readable consent policies, coordinates settlement, and writes the completed settlement back into the originating ERP.

The MVP is not designed to replace the ERP, issue credit, create an RWA marketplace, or act as a central clearing house.

The primary MVP product sequence is:

**ERP → Obligation → On-chain Token → Path Discovery → Policy Check → Settlement Instruction → P2P Settlement → ERP Reconciliation**

Longer-term functionality such as reputation, residual financing, RWA and broader Resourceconomy applications is outside MVP unless explicitly added in a later release.

---

# 3. Problem Statement

SMEs frequently experience working-capital pressure while simultaneously holding receivables, payables, invoices, goods commitments and service commitments.

Existing ERP systems record these obligations company-by-company. Existing finance products typically respond to timing mismatches by providing new liquidity through loans, factoring or supply-chain finance.

Orbitas addresses a preceding opportunity:

> Before adding new money, determine whether existing obligations can be redirected and cleared against each other.

A simple path:

- A owes B
- B owes C

may allow a settlement instruction in which A settles directly to C for the matched amount, reducing the settlement burden on B.

The user problem is therefore not merely "find invoice cycles." It is:

> Identify which existing obligations can be safely redirected through local paths, under participant-defined constraints, so that less external cash is required for settlement.

---

# 4. Product Objective

The MVP must prove that an ERP-native P2P clearing workflow can:

1. ingest real business obligations from Odoo;
2. represent both monetary and goods/service obligations in one product model;
3. create a verifiable on-chain representation of each published obligation;
4. discover path-enabled clearing opportunities;
5. enforce pre-defined consent policies;
6. execute clearing without a central clearing house acting as principal;
7. prevent double settlement;
8. reconcile completed settlement back into the ERP;
9. measure actual successfully settled value;
10. charge only on successfully settled value.

---

# 5. Goals and Success Metrics

## 5.1 Product goals

### G-01 — Reduce required cash settlement

Enable businesses to discharge or redirect existing obligations through clearing before resorting to external financing.

### G-02 — Make clearing ERP-native

Allow companies to use Orbitas without abandoning or duplicating their accounting workflow.

### G-03 — Make obligations machine-actionable

Represent ERP-backed obligations in a common model that can be evaluated and settled across company boundaries.

### G-04 — Make settlement P2P

Avoid requiring a central clearing operator to become principal to the obligation or payment.

### G-05 — Minimize disclosure

Allow participants to evaluate local clearing opportunities without exposing their full supplier/customer graph.

### G-06 — Establish measurable economic value

Tie product usage and billing to completed settlement, not merely to discovered or accepted proposals.

## 5.2 North-star metric

**Successfully Settled Value (SSV)**

Definition:

Total value of obligations successfully settled through Orbitas during the measurement period.

For monetary obligations, SSV is denominated in the obligation currency and may also be normalized for reporting.

For goods/services, SSV requires an agreed reference valuation for reporting. The settlement itself remains defined in the underlying resource units.

## 5.3 Supporting metrics

The MVP must measure:

- Eligible Obligation Volume
- Published / Tokenized Obligation Volume
- Candidate Clearing Value
- Accepted Proposal Value
- Successfully Settled Value
- Liquidity Relief Ratio
- Proposal Acceptance Rate
- Settlement Success Rate
- Average Time to Settlement
- Number of Active Companies
- Number of Active Obligation Tokens
- Number of Path Steps Executed
- ERP Reconciliation Success Rate
- Number / Rate of Failed or Rolled-Back Settlements
- Estimated External Cash Avoided
- Estimated Financing Avoided

## 5.4 Metric targets

No production KPI targets are approved yet.

Initial pilot targets MUST be defined after:
- selection of first jurisdiction;
- selection of pilot cluster;
- access to real Odoo obligation data.

Agents MUST NOT invent KPI thresholds before this validation.

---

# 6. User Segments and Personas

## 6.1 Primary persona — SME Finance Lead

Typical roles:
- CFO
- Finance Director
- Controller
- Treasury / working-capital manager
- Owner/CEO in smaller companies

Primary goals:
- reduce cash needed for payments;
- avoid or reduce borrowing;
- reduce late-payment risk;
- understand which obligations can be cleared;
- maintain accounting correctness.

Main concerns:
- counterparty exposure;
- legal/accounting treatment;
- privacy;
- operational safety;
- settlement certainty.

## 6.2 Secondary persona — Accountant / ERP Operator

Primary goals:
- preserve ERP as accounting source of truth;
- avoid duplicate entry;
- understand settlement references;
- reconcile settlements correctly.

Main concerns:
- incorrect postings;
- duplicate settlement;
- unclear audit trail;
- mismatch between blockchain state and ERP state.

## 6.3 Secondary persona — Business Owner / Authorized Signer

Primary goals:
- approve policies and exceptional settlements;
- control exposure to unknown counterparties;
- understand financial benefit.

## 6.4 Distribution persona — Odoo Partner / Integrator

Primary goals:
- deploy Orbitas into a connected customer cluster;
- configure connector and onboarding;
- support operational integration;
- create additional recurring value for installed Odoo clients.

## 6.5 Future personas

Not part of MVP product scope:
- bank / financier;
- investor;
- insurer;
- RWA buyer;
- freelancer;
- consumer IOU user.

---

# 7. Jobs To Be Done

## JTBD-01

When my company is waiting to receive money while also owing money to others, I want to know whether these obligations can be redirected or cleared so that I need less cash.

## JTBD-02

When Orbitas proposes a new settlement path, I want to know who pays whom, what original obligations are affected, what remains outstanding, and whether the proposal fits my company policy.

## JTBD-03

When a settlement completes, I want my ERP to reflect the result without manual reconstruction.

## JTBD-04

When my company publishes an obligation into Orbitas, I want the obligation to be uniquely represented and protected from double settlement.

## JTBD-05

When a proposed path introduces a new payer/receiver relationship, I want my pre-defined exposure rules to decide whether it is acceptable.

## JTBD-06

When the obligation represents goods or services rather than money, I want Orbitas to preserve the actual resource, quantity, unit, delivery/maturity and acceptance conditions.

---

# 8. Primary User Journeys

# 8.1 Journey A — Company onboarding

1. User installs or connects the Orbitas Odoo integration.
2. User authenticates the organization.
3. User connects or creates the organization's blockchain account/wallet.
4. User reviews permissions requested by Orbitas.
5. User configures a default consent policy.
6. System completes initial ERP synchronization.
7. User sees eligible obligations that can be published.

Outcome:
Company is ready to publish selected obligations into the P2P clearing network.

---

# 8.2 Journey B — Publish an obligation

1. User views eligible monetary, goods, or service obligations from Odoo.
2. User selects an obligation for Orbitas clearing.
3. System displays normalized obligation details.
4. System prepares evidence references and document hashes.
5. User confirms publication.
6. Orbitas creates the on-chain token representation.
7. System links token, ERP record, and evidence reference.
8. Obligation becomes discoverable according to the selected disclosure rules.

Outcome:
A clearing-eligible, uniquely represented obligation exists in the Orbitas network.

---

# 8.3 Journey C — Discover monetary path clearing

Example:

- A owes B: 100
- B owes C: 80

Flow:

1. Clearing agent detects path A → B → C.
2. Product computes matched amount = 80.
3. Product produces proposed redirect settlement A → C = 80.
4. Product shows residual A → B = 20 and residual B → C = 0.
5. Product evaluates consent policies of required participants.
6. Proposal is either:
   - auto-accepted;
   - sent for manual approval;
   - rejected as policy-ineligible.

Outcome:
A valid clearing proposal is ready for settlement.

---

# 8.4 Journey D — Discover goods/service path clearing

Example:

- A owes B: delivery of goods X
- B owes C: service Y

The product MUST NOT assume that unlike resources are numerically interchangeable.

Flow:

1. Product finds a structural path.
2. Product determines whether the resulting resource obligation is acceptable to the receiver.
3. Product checks:
   - resource type;
   - quantity/unit;
   - delivery/maturity;
   - location if relevant;
   - participant policy;
   - any explicit equivalence/valuation rule applicable to the path.
4. If no accepted equivalence or resource acceptance exists, proposal is not executable.
5. If conditions are satisfied, product produces a proposed redirected fulfillment/settlement instruction.

Outcome:
Only policy-compatible and explicitly valued/accepted resource paths can proceed.

**Needs Approval:** exact MVP mechanism for unlike-resource equivalence is specified in Section 18 as an open product decision.

---

# 8.5 Journey E — Settlement

1. Accepted proposal enters settlement preparation.
2. Product verifies that source obligations remain available.
3. Relevant tokenized quantities/amounts are locked.
4. Product records required consent evidence.
5. P2P settlement instruction is executed.
6. Product updates tokenized obligation states.
7. Product records completed settlement.
8. Residual obligations are updated.
9. ERP write-back/reconciliation begins.
10. Billing event is created only for successfully settled value.

Outcome:
The clearing has economic finality and is reflected in both Orbitas and the source ERP.

---

# 8.6 Journey F — Failure / rollback

1. A settlement fails before finality.
2. Product records failure reason.
3. Reserved/locked obligation value is released unless already finalized.
4. No billing event is created for the failed amount.
5. User sees whether retry is possible.
6. ERP MUST NOT be reconciled as successfully settled.

Outcome:
No partial hidden state is left inconsistent.

---

# 9. Scope

## 9.1 In scope

### ERP
- Odoo integration
- organization onboarding
- obligation import
- ERP-to-Orbitas normalization
- settlement write-back/reconciliation

### Obligations
- monetary invoices/payables/receivables
- goods obligations
- service obligations
- supporting evidence references
- on-chain tokenization of every published obligation

### Clearing
- local path-enabled clearing
- bilateral cases as special path cases
- cycle cases where discovered through path execution
- path eligibility checks
- proposal creation
- residual obligation calculation

### Consent
- pre-defined consent policies
- automated policy evaluation
- manual approval fallback
- policy-based exposure control

### Settlement
- P2P settlement coordination
- obligation locking/reservation
- prevention of double settlement
- redirect payment/fulfillment instruction
- settlement audit trail
- final state recording

### Billing
- usage measurement based on successfully settled value

### Privacy
- minimum necessary disclosure
- off-chain/IPFS evidence
- hashes/references on-chain

### AI / agents
- discovery assistance
- proposal ranking
- explanation
- policy configuration assistance
- anomaly detection
- orchestration

---

## 9.2 Out of scope

- central clearing house as mandatory counterparty
- automatic legal novation
- generalized credit/admission scoring
- universal credit rating
- factoring
- lending
- RWA origination
- external investment marketplace
- public obligation DEX
- AMM
- public speculative trading
- freelancer passport
- Learn2Earn
- SocialFi
- housing/rental application
- consumer IOUs
- DAO/Soprocvetanie governance
- DisPOS as MVP dependency
- new global Orbitas blockchain
- advanced ZKP privacy
- universal DID stack
- regulator-specific automation for all jurisdictions
- standalone cycle optimizer

---

# 10. Assumptions and Dependencies

## 10.1 Approved assumptions / constraints

### A-01
Odoo is the first ERP connector.

### A-02
Architecture must support later adapters for QuickBooks, 1C and other ERP systems.

### A-03
Every obligation published for clearing receives an on-chain token representation.

### A-04
Evidence remains off-chain/IPFS, with hashes and references linked to the on-chain state.

### A-05
ERP remains canonical for original accounting records.

### A-06
On-chain contract state is canonical for clearing-related token state, locks and settlement state.

### A-07
Settlement is P2P.

### A-08
Settlement instruction is redirect payment/fulfillment, not automatic legal novation.

### A-09
Consent is primarily pre-defined policy driven.

### A-10
Successfully settled value is the charging event.

### A-11
Separate cycle optimization is not required for MVP.

## 10.2 Dependencies

- Odoo API/module access
- blockchain network and contract deployment environment
- IPFS or equivalent off-chain document storage
- wallet / signing flow
- company/entity identity mapping
- legal review for initial jurisdiction
- accounting treatment for redirect settlement
- pilot participant cluster
- real business obligation data for validation

---

# 11. Product Requirements

Requirements use the format `PR-<area>-NNN`.

---

## 11.1 Organization & onboarding

### PR-ORG-001 — Organization registration

The product SHALL allow an authorized user to create or connect an Orbitas organization corresponding to a business entity.

**User value:** establishes a persistent participant identity.

### PR-ORG-002 — ERP connection

The product SHALL allow an authorized user to connect an Odoo instance/account to the Orbitas organization.

### PR-ORG-003 — Wallet/signing account

The product SHALL allow the organization to associate an authorized blockchain signing account.

### PR-ORG-004 — Permission transparency

Before ERP access is activated, the user SHALL be shown the categories of ERP data Orbitas can read and write.

### PR-ORG-005 — Consent policy initialization

The onboarding flow SHALL require the organization to define or explicitly select a default consent behavior before automatic clearing acceptance is enabled.

---

## 11.2 ERP obligation import

### PR-ERP-001 — Read eligible obligations

Orbitas SHALL read supported Odoo records representing monetary, goods and service obligations.

### PR-ERP-002 — Preserve source reference

Every imported obligation SHALL retain an immutable reference to the source ERP record.

### PR-ERP-003 — Normalize into common model

Odoo-specific records SHALL be presented to the product as Orbitas `Obligation` objects.

### PR-ERP-004 — No mandatory duplicate accounting

Users SHALL NOT be required to recreate their accounting records manually in Orbitas.

### PR-ERP-005 — Import status visibility

The product SHALL show whether an obligation is:
- ERP-only;
- imported;
- published;
- locked;
- partially settled;
- settled;
- failed/disputed as applicable.

---

## 11.3 Obligation representation

### PR-OBL-001 — Universal obligation type

The product SHALL support:
- monetary;
- goods;
- service

obligations without reducing all obligations to a money-only schema.

### PR-OBL-002 — Core obligation data

Each obligation SHALL expose product-level information sufficient to understand:
- who owes;
- who is owed;
- what is owed;
- amount/quantity;
- unit/currency where relevant;
- maturity/due date;
- source;
- evidence reference;
- clearing state.

### PR-OBL-003 — Partial settlement

The product SHALL support partial clearing of an obligation and maintain the residual amount/quantity.

### PR-OBL-004 — Evidence linkage

Every published obligation SHALL have evidence provenance sufficient to link the tokenized obligation to its ERP/document source.

### PR-OBL-005 — Resource-specific semantics

Goods/service obligations SHALL preserve attributes required to determine fulfillment acceptability, such as quantity, unit, specification, delivery date and location where applicable.

---

## 11.4 On-chain publication

### PR-TOK-001 — Tokenize every published obligation

Every obligation published into the clearing network SHALL receive an on-chain token representation.

### PR-TOK-002 — Unique mapping

The product SHALL maintain a unique relationship between:
- Orbitas obligation;
- source ERP obligation;
- on-chain token representation.

### PR-TOK-003 — Evidence reference

On-chain state SHALL reference documentary evidence through hash and URI/reference rather than store full sensitive documents by default.

### PR-TOK-004 — State visibility

The product SHALL expose a human-readable state derived from the authoritative clearing token state.

### PR-TOK-005 — Prevent over-consumption

The tokenized obligation state SHALL prevent more value/quantity from being committed to settlements than remains available.

---

## 11.5 Consent policies

### PR-POL-001 — Machine-readable policies

Users SHALL be able to configure consent rules that the product can evaluate automatically.

### PR-POL-002 — Exposure constraints

Policies SHALL support limits on redirected exposure.

### PR-POL-003 — Counterparty constraints

Policies SHOULD support whitelist/blacklist or equivalent counterparty controls.

### PR-POL-004 — Resource constraints

Policies SHALL support acceptance by resource type and relevant resource attributes.

### PR-POL-005 — Maturity constraints

Policies SHALL support due-date/maturity constraints.

### PR-POL-006 — Manual fallback

If an otherwise valid proposal does not meet auto-accept conditions but is not explicitly prohibited, the product MAY route it for manual approval.

### PR-POL-007 — Explain decision

The product SHALL show why a proposal was:
- auto-accepted;
- sent for approval;
- rejected.

---

## 11.6 Path discovery

### PR-CLR-001 — Local path discovery

The product SHALL discover candidate clearing paths using obligations that can be matched through one or more local path-enabled reductions.

### PR-CLR-002 — Monetary matched amount

For compatible monetary obligations, the product SHALL calculate the maximum matched amount for the proposed local step, subject to policies and available obligation value.

### PR-CLR-003 — No cycle dependency

The product SHALL NOT require a directed cycle to discover a valid clearing opportunity.

### PR-CLR-004 — Path eligibility

A candidate path SHALL be executable only when all required policy, resource and settlement constraints are satisfied.

### PR-CLR-005 — Residual visibility

Before approval or automatic acceptance, the product SHALL show the effect on each affected obligation and the resulting residual state.

### PR-CLR-006 — Deterministic result

Given the same obligation state, policies and deterministic ordering/rules, the core clearing result SHALL be reproducible.

### PR-CLR-007 — Proposal ranking

The product MAY rank multiple valid proposals by expected user value, but ranking SHALL NOT alter the deterministic settlement rules.

---

## 11.7 Goods and service clearing

### PR-RES-001 — Structural path vs executable path

The product SHALL distinguish between:
- structurally connected resource paths;
- executable resource clearing paths.

### PR-RES-002 — No implicit fungibility

The product SHALL NOT treat unlike goods/services as automatically interchangeable.

### PR-RES-003 — Explicit acceptability

A redirected goods/service obligation SHALL proceed only if the receiving participant's policy or explicit approval accepts the resulting resource obligation.

### PR-RES-004 — Reference valuation

When reporting cross-resource Successfully Settled Value, the product SHALL use an explicit reference valuation source attached to the settlement.

The product SHALL NOT silently create a global market price.

---

## 11.8 Clearing proposal

### PR-PRO-001 — Proposal explanation

Each proposal SHALL clearly show:
- source obligations;
- proposed payer/fulfiller;
- proposed receiver;
- settled amount/quantity;
- residual obligations;
- due date;
- reason the path is eligible;
- consent status.

### PR-PRO-002 — Economic benefit

For monetary clearing, the product SHOULD show estimated external cash settlement avoided.

### PR-PRO-003 — Proposal lifecycle

A proposal SHALL have visible lifecycle state, such as:
- candidate;
- policy evaluation;
- awaiting approval;
- accepted;
- locked;
- settling;
- settled;
- failed;
- expired/cancelled.

Exact state names may be refined in SRS/TRD.

---

## 11.9 P2P settlement

### PR-SET-001 — No central principal

Orbitas SHALL coordinate settlement without requiring Orbitas itself to become debtor, creditor, buyer, seller or principal to the underlying obligations.

### PR-SET-002 — Redirect instruction

The MVP SHALL represent path settlement as redirect payment/fulfillment instructions rather than automatic novation.

### PR-SET-003 — Lock before execution

Affected tokenized obligation value/quantity SHALL be reserved/locked before final settlement execution.

### PR-SET-004 — Prevent double settlement

An amount/quantity already locked or settled SHALL NOT be available to an incompatible settlement.

### PR-SET-005 — Finality visibility

Users SHALL be able to distinguish pending settlement from successfully settled value.

### PR-SET-006 — Failure handling

If settlement fails before finality:
- non-finalized locks SHALL be releasable;
- billing SHALL NOT occur for the failed amount;
- ERP SHALL NOT record a completed settlement.

### PR-SET-007 — Audit trail

The product SHALL preserve a traceable record of:
- obligations used;
- policies/consents;
- settlement instruction;
- final result.

---

## 11.10 ERP reconciliation

### PR-REC-001 — Write-back

Successfully settled obligations SHALL be reflected back into Odoo using an auditable reconciliation/write-back process.

### PR-REC-002 — Source linkage

ERP records created or updated by Orbitas SHALL contain or preserve a reference to the related Orbitas settlement.

### PR-REC-003 — Partial reconciliation

If only part of an obligation is settled, the ERP workflow SHALL preserve the residual outstanding obligation.

### PR-REC-004 — Error visibility

If on-chain settlement succeeds but ERP write-back fails, the product SHALL show an explicit reconciliation exception requiring resolution.

The economic settlement MUST NOT be silently rolled back solely because of an ERP write-back failure if settlement finality already exists.

---

## 11.11 Billing

### PR-BIL-001 — Successful settlement only

A billable event SHALL be created only for successfully settled value.

### PR-BIL-002 — Partial billing

For partial settlement, only the successfully settled portion SHALL be billable.

### PR-BIL-003 — No proposal billing

Candidate, accepted, expired or failed proposals SHALL NOT themselves constitute a settlement-fee event.

### PR-BIL-004 — Traceability

Every billable event SHALL be traceable to one or more finalized settlement records.

The fee percentage is TBD and is not defined by this PRD.

---

# 12. UX / Design Considerations

## 12.1 UX principle

The product SHOULD present the business effect first and protocol mechanics second.

Prefer:
> "You can settle 80,000 directly and reduce your cash requirement."

over:
> "Execute token graph compression."

## 12.2 Core screens / product surfaces

The MVP is expected to require at least:

1. Organization onboarding
2. Odoo connection / sync status
3. Obligation list
4. Obligation details / evidence / token status
5. Consent Policy configuration
6. Clearing Opportunities
7. Clearing Proposal detail
8. Approval queue
9. Settlement status
10. Reconciliation exceptions
11. Activity / audit trail
12. Usage / Successfully Settled Value

Design artifacts are not yet approved.

## 12.3 Proposal visualization

For path proposals, the UI SHOULD visually communicate before/after state.

Example:

Before:
`A → B: 100`
`B → C: 80`

After:
`A → B: 20`
`A → C settlement: 80`
`B → C: 0`

## 12.4 Trust visibility

Users SHOULD be able to see:
- source ERP reference;
- token status;
- evidence availability;
- consent status;
- settlement finality.

The UI MUST NOT imply that Orbitas legally guarantees an obligation merely because it is tokenized.

---

# 13. Product-Level Non-Functional Expectations

These expectations are product requirements; technical thresholds belong in the TRD/SRS.

## NFR-P-01 — Auditability

Business-critical state transitions must be reconstructable from system records.

## NFR-P-02 — Determinism

Settlement calculations and final business state transitions must be reproducible.

## NFR-P-03 — Privacy

The user experience must not require disclosure of unrelated ERP data or the full commercial graph.

## NFR-P-04 — Integrity

The product must prevent double use of the same obligation quantity/value.

## NFR-P-05 — Availability visibility

When network, ERP, blockchain or IPFS dependencies are unavailable, the product must expose the degraded state rather than present stale data as final.

## NFR-P-06 — Explainability

Users must be able to understand why a clearing proposal is possible and why policy allowed or rejected it.

## NFR-P-07 — ERP portability

Product concepts must remain independent from Odoo-specific terminology where practical.

## NFR-P-08 — Idempotency

Retrying synchronization or settlement-related product actions must not create duplicate obligations or duplicate settlements.

Detailed technical SLOs, cryptographic choices and architecture are downstream TRD/SRS decisions.

---

# 14. AI / Agent Product Requirements

Orbitas may use AI/agentic components for orchestration, but financial finality must remain deterministic.

## 14.1 Expected AI behavior

AI MAY:
- summarize ERP/document context;
- recommend obligations to publish;
- discover or prioritize candidate paths;
- explain clearing proposals;
- suggest consent-policy settings;
- predict which proposals may require manual review;
- identify anomalies or suspicious evidence;
- negotiate non-binding proposal alternatives.

## 14.2 AI SHALL NOT

AI SHALL NOT:
- invent obligations;
- modify authoritative amounts without deterministic source data;
- fabricate evidence;
- bypass policy constraints;
- create financial finality based on probabilistic output;
- silently change legal meaning;
- mark settlement complete without deterministic confirmation.

## 14.3 Human oversight

Human approval SHALL remain available for:
- proposals outside auto-consent policy;
- policy changes with material exposure implications;
- reconciliation exceptions;
- ambiguous resource equivalence;
- legal/accounting exceptions.

---

# 15. AI Evaluation Strategy

AI is not itself the clearing algorithm. Evaluation must therefore focus on assistance quality.

The MVP evaluation dataset SHOULD include representative cases for:

- correct explanation of proposals;
- correct mapping of user intent into policy configuration;
- correct flagging of missing information;
- refusal to invent unsupported obligation/evidence data;
- correct escalation to manual review;
- candidate-path ranking quality where AI ranking is used.

Required evaluation principles:

1. deterministic settlement output is the reference truth;
2. AI suggestions must never override invalid deterministic paths;
3. hallucinated obligations/evidence are critical failures;
4. false claims of settlement finality are critical failures;
5. policy explanations must reference actual evaluated rules.

Numeric model-quality thresholds are TBD and MUST be established after representative test data exists.

---

# 16. Observability and Runtime Feedback

The product must capture:

- ERP sync failures;
- token publication failures;
- policy evaluation outcomes;
- candidate/accepted/rejected proposals;
- locks and releases;
- settlement attempts;
- settlement failures;
- reconciliation failures;
- billing-event creation;
- AI recommendation acceptance/rejection where AI is used.

For AI-assisted behavior, log enough structured context to answer:
- what the AI recommended;
- what deterministic rules allowed;
- what the user approved;
- what actually executed.

Sensitive raw documents should not be copied into observability systems by default.

---

# 17. Risks and Trade-offs

## R-01 — Legal treatment of redirected payment

Risk:
Redirect settlement may have different legal/accounting effects by jurisdiction.

Mitigation:
Keep MVP semantics as settlement instruction, not automatic novation; obtain jurisdiction-specific legal review.

## R-02 — Goods/services complexity

Risk:
Unlike resources are not naturally fungible.

Mitigation:
Require explicit acceptability/equivalence rather than global implicit conversion.

## R-03 — ERP data quality

Risk:
Incorrect or stale obligations lead to invalid proposals.

Mitigation:
Source references, synchronization state, pre-settlement revalidation.

## R-04 — Double settlement

Risk:
Concurrent proposals attempt to consume the same obligation.

Mitigation:
On-chain locking/reservation and deterministic state validation.

## R-05 — P2P coordination friction

Risk:
Settlement may fail because parties or agents are offline/unavailable.

Mitigation:
Visible proposal lifecycle, retries, expirations, deterministic unlock.

## R-06 — Privacy concerns

Risk:
Businesses refuse participation if commercial graph disclosure is excessive.

Mitigation:
Local path model and minimum necessary disclosure.

## R-07 — Blockchain UX friction

Risk:
Wallets, signatures and gas concepts reduce adoption.

Mitigation:
Business-first UX and abstraction of protocol mechanics where feasible.

## R-08 — Cross-system reconciliation

Risk:
Settlement succeeds while ERP update fails.

Mitigation:
Separate economic finality from reconciliation status and support exception recovery.

## R-09 — Network cold start

Risk:
Too few connected counterparties produce limited clearing opportunities.

Mitigation:
Pilot through connected Odoo partner/anchor-business clusters.

---

# 18. Open Product Questions for Approval

These items are intentionally not silently resolved in this PRD.

## OQ-PRD-01 — First jurisdiction

Preferred investigation:
- Mexico
- Brazil
- Peru

Need decision before legally binding production pilot.

## OQ-PRD-02 — Unlike-resource equivalence in MVP

For goods/service paths where unlike resources are exchanged, choose the MVP rule:

### Option A — Explicit bilateral/policy quote only — RECOMMENDED
A path is eligible only when the receiving party has explicitly defined that resource X is accepted for obligation Y at a specified ratio/quantity.

Advantages:
- deterministic;
- no global price engine;
- clear consent;
- smallest MVP scope.

### Option B — External reference-price conversion
Use agreed external reference values to compare unlike resources.

Advantages:
- more matching opportunities.

Risks:
- oracle/source disputes;
- may unintentionally turn clearing into market pricing.

### Option C — Agent-negotiated quote
Agents negotiate an ad hoc equivalence and request approval.

Advantages:
- flexible.

Risks:
- more product complexity;
- harder deterministic automation.

**Recommendation for MVP:** Option A, with manual approval fallback.

## OQ-PRD-03 — Fee rate

Charging event is approved as Successfully Settled Value, but actual fee percentage / pricing tiers are TBD.

## OQ-PRD-04 — Blockchain deployment target

On-chain tokenization is required, but specific chain/L2 is a downstream architecture decision unless business/legal constraints force one.

## OQ-PRD-05 — Staking use in MVP

The canonical state includes a staking-capable contract concept, but the exact MVP staking behavior is not yet specified.

Need to decide whether MVP includes:
- staking only as contract capability with no active product flow;
- issuer stake;
- third-party guarantee stake;
- no active staking until post-MVP.

This decision should be made before TRD finalization.

---

# 19. Release Criteria

The MVP is release-ready for a controlled pilot only when all mandatory criteria are met.

## RC-01 — Odoo onboarding works

A pilot company can connect Odoo and synchronize supported obligations.

## RC-02 — Universal obligation model works

At least:
- one monetary obligation flow;
- one goods OR service obligation flow

can be represented end-to-end.

## RC-03 — On-chain tokenization works

Every published pilot obligation receives a unique token representation linked to evidence.

## RC-04 — Consent policies work

The product can auto-accept, reject, or route proposals for manual approval based on configured policies.

## RC-05 — Path clearing works

The product can execute a valid open-path clearing case without requiring a cycle.

## RC-06 — P2P settlement works

A pilot settlement can complete without Orbitas becoming principal.

## RC-07 — Double settlement is prevented

Concurrency tests confirm that the same obligation value cannot be finalized twice.

## RC-08 — ERP write-back works

A successful settlement can be reconciled back into Odoo.

## RC-09 — Failure behavior works

Failed settlement and failed reconciliation cases are visible, recoverable and do not create false billing.

## RC-10 — Billing event works

Only successfully settled value creates the corresponding billable usage event.

## RC-11 — Auditability works

A reviewer can trace a completed settlement from ERP source obligation through tokenization, consent, settlement and reconciliation.

## RC-12 — Legal pilot boundary is approved

The selected pilot jurisdiction and legal/accounting treatment have been reviewed before production use with real third-party obligations.

---

# 20. Pilot Readiness Checklist

Before pilot launch:

- [ ] jurisdiction selected
- [ ] pilot legal/accounting flow reviewed
- [ ] Odoo connector ready
- [ ] company/entity onboarding ready
- [ ] on-chain contracts deployed
- [ ] evidence storage operational
- [ ] consent policies available
- [ ] monetary clearing test passed
- [ ] resource obligation test passed
- [ ] double-settlement tests passed
- [ ] reconciliation tests passed
- [ ] settlement failure tests passed
- [ ] audit trail verified
- [ ] billing event verified
- [ ] participant support process defined
- [ ] pilot cluster identified
- [ ] KPI baseline collection enabled

---

# 21. Downstream Artifacts

After PRD approval, AI agents should produce:

1. **TRD / Architecture Specification**
   - system boundaries;
   - P2P topology;
   - contract architecture;
   - IPFS/evidence architecture;
   - identity/signing;
   - state synchronization;
   - failure model.

2. **SRS**
   - detailed state machines;
   - API behavior;
   - error handling;
   - data contracts;
   - NFR thresholds.

3. **Odoo Connector Specification**
   - source models;
   - mapping rules;
   - write-back semantics.

4. **Orbitas Domain Model Specification**
   - Entity;
   - Obligation;
   - Evidence;
   - ConsentPolicy;
   - SettlementInstruction;
   - Settlement.

5. **Clearing Engine Specification**
   - deterministic Byppay/path rules;
   - ordering;
   - resource compatibility;
   - eligibility evaluation;
   - concurrency behavior.

6. **Smart Contract Specification**
   - obligation token;
   - locking;
   - settlement state;
   - evidence references;
   - staking decision once approved.

7. **UX Flows / Wireframes**
   - onboarding;
   - obligations;
   - policy configuration;
   - proposals;
   - settlement;
   - reconciliation exceptions.

8. **Test & Evaluation Plan**
   - business-rule tests;
   - settlement invariants;
   - concurrency;
   - integration;
   - AI-assistance evaluation.

9. **Pilot Runbook**
   - onboarding;
   - support;
   - exception resolution;
   - rollback/reconciliation procedures;
   - measurement.

---

# 22. PRD Approval Gate

This document should move from **Draft** to **Approved** only after explicit decisions on:

1. `OQ-PRD-02` — unlike-resource equivalence rule;
2. `OQ-PRD-05` — staking behavior in MVP;
3. confirmation that the current product journeys and scope match the intended MVP.

`OQ-PRD-01` jurisdiction may remain TBD during engineering of the jurisdiction-neutral core, but must be closed before production pilot.

`OQ-PRD-03` fee rate may remain TBD during core product development because the charging event itself is already fixed.

`OQ-PRD-04` chain target should be resolved in TRD unless legal/product constraints require an earlier choice.

---

# 23. Proposed Approval Decisions

For approval, the Product Owner is asked to confirm:

### DEC-PRD-01
Approve the PRD scope as:
**Odoo-first P2P path-enabled clearing for tokenized monetary + goods/service obligations.**

### DEC-PRD-02
Approve unlike-resource MVP rule:
**Option A — explicit participant-defined equivalence/acceptance, with manual fallback.**

### DEC-PRD-03
Approve product-level settlement semantics:
**redirect payment/fulfillment instruction; no automatic novation.**

### DEC-PRD-04
Approve consent behavior:
**pre-defined machine-readable policies + manual exception flow.**

### DEC-PRD-05
Approve billing behavior:
**only successfully settled value is billable.**

### DEC-PRD-06
Choose staking scope:
- A. contract capability only, no active staking UI/flow in MVP;
- B. issuer staking in MVP;
- C. issuer + third-party guarantee staking in MVP.

**Recommendation:** A for the first clearing release, unless staking is required for the intended trust model of the pilot.

---

# 24. Compact Product Contract

If context is constrained, preserve this:

> Orbitas MVP is an Odoo-first P2P clearing product for SMEs. Monetary invoices and goods/service obligations are normalized into a universal obligation model and every published obligation receives an on-chain token representation linked to off-chain/IPFS evidence. A deterministic path-enabled clearing engine discovers open-path settlement opportunities, evaluates participant-defined consent policies, locks affected obligations, coordinates redirect payment/fulfillment instructions without automatic novation, finalizes settlement P2P, and reconciles the result back into Odoo. Orbitas bills only successfully settled value. A central clearing house, separate cycle optimizer, factoring/RWA, public markets, universal credit scoring, DisPOS and unrelated Resourceconomy verticals are out of MVP.
