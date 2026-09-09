# Orbitas — Business Requirements Document (BRD)

**Version:** 1.0 Approved baseline  
**Date:** 2026-09-09  
**Primary MVP:** P2P clearing network for ERP-backed tokenized business obligations  
**Initial ERP:** Odoo  
**Next connectors:** QuickBooks Online, 1C:Enterprise

## 1. Executive Summary

Orbitas is an ERP-native P2P clearing network for SMEs. It connects existing accounting systems, converts published business obligations into on-chain tokenized obligations linked to off-chain/IPFS evidence, finds path-enabled clearing opportunities, applies participant-defined consent policies, coordinates P2P settlement, and reconciles completed settlement back into the source ERP.

Core sequence:

`ERP data → participant passport → tokenized obligation → path-enabled clearing → settlement → ERP reconciliation`

Longer-term sequence:

`ERP data → tokenized obligation → clearing → residual obligation → financing/RWA → broader Resourceconomy`

The MVP optimizes the first sequence.

## 2. Business Problem

SMEs often simultaneously hold receivables, payables, invoices, goods commitments and service commitments, but their ERP systems are isolated by company. Banks and factoring products inject new liquidity; Orbitas first asks whether existing obligations can be redirected or mutually discharged before new money is borrowed.

The foundational economic case is the debt-chain pattern in which the same unit of settlement can discharge multiple obligations. Resourceconomy extends this logic from money into resource/time/multi-step exchange, and path-enabled invoice clearing formalizes an executable local rule for open chains.

## 3. Business Goal

Reduce the amount of external cash and working-capital financing SMEs need to settle already-existing trade obligations.

## 4. Primary Users

- SME CFO / Finance Director
- Owner/CEO of smaller firms
- Accountant / AP / AR staff
- Treasury / working-capital manager
- Odoo / ERP implementation partner as distribution channel

## 5. Primary Business Outcomes

Orbitas must enable a business to:

1. connect its ERP without migrating accounting;
2. self-register a participant passport;
3. publish selected monetary, goods and service obligations;
4. create an on-chain representation for every published obligation;
5. discover bilateral and open-path clearing opportunities;
6. apply predefined consent policies;
7. execute P2P redirect settlement without Orbitas becoming principal;
8. prevent double use/double settlement;
9. reconcile completed settlement back into the ERP;
10. charge only on successfully settled value.

## 6. Approved Business Decisions

| ID | Decision |
|---|---|
| BR-D01 | MVP supports monetary invoices and goods/service obligations |
| BR-D02 | Settlement instruction is redirect payment/fulfillment, not automatic novation |
| BR-D03 | Consent uses predefined machine-readable policies with manual exception flow |
| BR-D04 | MVP economic topology is P2P |
| BR-D05 | Generalized minimum verification/admission score is out of MVP |
| BR-D06 | Every published ERP obligation is tokenized on-chain |
| BR-D07 | Canonical state is hybrid: ERP accounting + IPFS/off-chain evidence + on-chain clearing state |
| BR-D08 | First jurisdiction is TBD; preferred exploration: Mexico, Brazil, Peru |
| BR-D09 | Charging event is Successfully Settled Value |
| BR-D10 | Path-enabled clearing is sufficient; no separate cycle optimizer required |
| BR-D11 | Participant passport issuance is self-service and SELF_DECLARED in MVP |
| BR-D12 | Obligation is a multidimensional token `T=(R,Q,S)` |
| BR-D13 | Stake/guarantee does not rewrite observed quality; it affects acceptability under participant policy |

## 7. Business Model Boundary

Orbitas MVP is not a bank, factoring company, RWA marketplace, public DEX/AMM, central clearing house, replacement ERP, universal credit bureau or consumer IOU product.

## 8. North-Star Metric

**Successfully Settled Value (SSV)** — value of obligations actually settled through Orbitas.

Supporting metrics:

- eligible obligation volume;
- published/tokenized volume;
- candidate clearing value;
- accepted proposal value;
- SSV;
- liquidity relief ratio;
- proposal acceptance rate;
- settlement success rate;
- time to settlement;
- ERP reconciliation success;
- estimated cash/financing avoided.

No numerical KPI targets are approved until a real pilot dataset is available.

## 9. Business Acceptance Criteria

The MVP is validated only if a real connected SME cluster demonstrates:

- ERP import of real obligations;
- measurable path-enabled clearing opportunities;
- participant willingness to consent;
- successful P2P settlement;
- correct ERP reconciliation;
- SSV large enough to exceed product and coordination cost.

## 10. GTM Principle

The preferred acquisition motion is ERP/accounting partner cluster activation: an integrator connects a group of existing customers that already trade with one another. The strategic moat is cross-ERP settlement; the distribution wedge is the ERP/accounting partner.

## 11. Open Business Decision

**First production jurisdiction** remains TBD among Mexico, Brazil and Peru. Core architecture must stay jurisdiction-neutral.
