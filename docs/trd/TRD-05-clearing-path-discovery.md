# TRD-05 — Clearing Path Discovery Service

**Status:** Draft for approval — multidimensional obligation revision 0.91  
**Depends on:** TRD-04, TRD-03  
**AI:** optional; deterministic algorithm is mandatory  
**Primary algorithm:** path-enabled local compensation (Byppay-style), not cycle-restricted optimization

## 1. Objective

Discover executable P2P clearing opportunities across tokenized business obligations.

The mandatory core is deterministic.

AI/LLM components may:
- rank candidate paths;
- explain proposals;
- help interpret non-binding business metadata;
- suggest policy settings.

AI MUST NOT:
- invent obligations;
- create settlement quantities;
- bypass consent;
- decide financial finality;
- replace deterministic path validation.

## 2. Economic primitive

For a monetary/same-resource local path:

```text
A --x--> B --y--> C
```

matched quantity:

```text
d = min(x, y)
```

Proposed redirect:

```text
A --------d-------> C
```

Residual:
- A→B becomes `x-d`
- B→C becomes `y-d`

The underlying claims are not automatically novated. The proposal creates a settlement instruction.

## 3. Why path-enabled

Cycle-only netting requires closed directed cycles.

Orbitas MVP instead uses local two-edge paths and may repeatedly apply local reductions.

Consequences:
- can act on open supply-chain paths;
- local information can be sufficient;
- bilateral netting is a special case;
- cycles are naturally handled through sequences of path operations;
- a separate cycle optimizer is not required.

## 4. Service boundary

```text
Obligation Index (TRD-04)
       │
       ▼
Path Discovery Engine
  ├─ snapshot builder
  ├─ local path enumerator
  ├─ resource compatibility
  ├─ consent policy evaluator
  ├─ deterministic ranking/tie-break
  └─ proposal builder
       │
       ▼
Participant Agents
       │ consent/signatures
       ▼
Obligation Contract locks/settlement
```

## 5. Input snapshot

A proposal must be derived from a versioned snapshot:

```json
{
  "chainId": "...",
  "indexedBlock": 123456,
  "participantScope": ["..."],
  "obligations": [],
  "policyRefs": [],
  "discoveryParameters": {
    "maxSteps": 100,
    "dueBefore": "...",
    "resourceFilter": null
  }
}
```

Before execution, every source obligation must be revalidated against TRD-03 canonical state.

## 6. Clearing eligibility

An obligation edge is eligible only when:
- status active/partially settled;
- available quantity > 0;
- required participants are onboarded;
- due-date constraints permit use;
- resource type/attributes are compatible with candidate step;
- participant consent policy allows proposal or routes it to manual approval;
- no active lock consumes the proposed quantity.

## 7. Resource compatibility

### 7.1 Monetary same currency

Direct quantitative path:
`d = min(availableAB, availableBC)`

### 7.2 Monetary different currencies

NOT implicitly convertible.

Requires explicit accepted conversion quote/policy.

### 7.3 Same goods/service resource

If resourceCode + unitCode + relevant specification are compatible:
`d = min(normalizedQuantityAB, normalizedQuantityBC)` after deterministic unit normalization.

### 7.4 Unlike goods/services

A structural path is not executable unless:
- an explicit participant-defined equivalence exists; or
- participants manually approve a specific quote.

Until a broader pricing/AMM decision exists, no global market-price inference is allowed.


## 7.5 Multidimensional quality/stake eligibility

Every executable edge is conceptually:

```text
e = (issuer, beneficiary, R, Q, S)
```

where:
- `R` = resource/properties;
- `Q` = evidence-derived quality vector;
- `S` = attribute-specific FOR/AGAINST stake or guarantees.

The final eligibility rule is:

\[
EligiblePath =
GraphPath
\cap ResourceCompatibility
\cap QualityConstraints
\cap ConsentConstraints
\]

A participant policy MAY contain requirements such as:

```yaml
quality:
  delivery.on_time:
    operator: ">="
    observed: 0.90
    minConfidence: 0.80

  issuer.default_probability:
    operator: "<"
    observed: 0.05

stake:
  claim: "delivery.on_time>=0.95"
  acceptedCollateral:
    - USDC
  minCoverage: 0.20
  maxAgainstStake: 0.05
```

The engine MUST distinguish:
- observed quality;
- evidence confidence;
- positive stake;
- negative stake.

It MUST NOT obtain an executable path by simply adding stake to the observed quality score.

If a policy defines an effective acceptance rule combining observation and stake, that rule must be:
- deterministic;
- explicit;
- participant-owned;
- auditable.

Example:

```text
accept if:
  observed_quality >= 0.80
OR
  observed_quality >= 0.70
  AND approved_positive_stake_coverage >= 0.30
  AND negative_stake_coverage <= 0.05
```

This permits capital backing to create new clearing connectivity without rewriting historical reputation.


## 8. Consent policy interface

```typescript
interface ConsentPolicyEvaluator {
  evaluate(
    participant: PassportId,
    proposal: CandidateProposal,
    localContext: PrivateLocalContext
  ): PolicyDecision;
}
```

Decision:

```text
AUTO_ACCEPT
MANUAL_APPROVAL
REJECT
```

Response must include rule explanations.

Policies may consider:
- counterparty whitelist/blacklist;
- resource type;
- maximum exposure;
- due date;
- currency;
- amount/quantity;
- jurisdiction;
- quality observation values and evidence confidence;
- attribute-specific FOR/AGAINST stake;
- collateral type/coverage;
- staker/guarantor constraints where configured.

## 9. Deterministic algorithm

### 9.1 Local step ordering

Recommended reproducible policy:
1. eligible intermediary `B`: lowest `passportId`;
2. incoming edge `A→B`: highest available quantity/value;
3. tie → lowest `obligationId`;
4. outgoing edge `B→C`: highest available compatible quantity/value;
5. tie → lowest `obligationId`.

Apply:
`d = min(availableAB, availableBC)` after normalization/policy cap.

This follows the project’s deterministic Byppay direction and avoids LLM-dependent final results.

### 9.2 Run modes

#### `DISCOVER_ONE_STEP`
Returns local opportunities without modifying graph.

#### `SIMULATE_FIXED_POINT`
Runs repeated virtual local reductions on a snapshot until no eligible step remains.

Used for:
- liquidity scanner;
- proposal planning;
- analytics.

#### `EXECUTE_STEPWISE`
Each accepted step is separately locked and settled. The graph is refreshed after finality.

Recommended MVP production mode.

## 10. Multi-hop paths

A longer path:

`A → B → C → D`

is represented as a sequence of local contractions, not a monolithic opaque optimization.

This improves:
- consent locality;
- failure recovery;
- auditability;
- P2P execution.

The service MAY present the user a combined multi-step proposal when all steps are prevalidated, but execution state remains decomposable.

## 11. Proposal model

```json
{
  "proposalId": "0x...",
  "snapshotBlock": 123,
  "steps": [
    {
      "intermediary": "passport:B",
      "incomingObligationId": "101",
      "outgoingObligationId": "204",
      "payerPassportId": "A",
      "receiverPassportId": "C",
      "quantity": "8000",
      "decimals": 2,
      "resourceCode": "BRL",
      "dueDate": "..."
    }
  ],
  "residuals": [],
  "policyDecisions": [],
  "estimatedLiquidityRelief": "...",
  "status": "CANDIDATE"
}
```

`proposalId` should commit to ordered source obligations, quantities, snapshot and nonce so mutation invalidates prior signatures.

## 12. Proposal API

### `POST /v1/clearing/discover`

Input:
- participant scope;
- resource filter;
- max steps;
- optional time horizon.

Output:
- candidate proposals.

### `POST /v1/clearing/simulate`

Returns fixed-point simulation and metrics without locks.

### `POST /v1/proposals/{id}/evaluate`

Evaluates current policies.

### `POST /v1/proposals/{id}/prepare-settlement`

Revalidates contract state and prepares typed lock/consent intents.

## 13. Optional AI layer

### Inputs allowed

- deterministic candidate proposals;
- public participant metadata;
- policy explanations;
- permitted private local metadata.

### Outputs allowed

- ranking score;
- natural-language explanation;
- "why this is useful";
- likely manual-review reasons;
- suggested policy edits.

### Guardrail

AI output is advisory.

Final executable proposal = deterministic candidate ∩ deterministic policy ∩ signed consent ∩ canonical contract availability.

## 14. Complexity target

For sparse invoice graphs, local path processing should be near:
- step count bounded by edge eliminations in simulation;
- optimized candidate selection using adjacency indexes/heaps;
- target algorithmic profile approximately `O(m log n)` for deterministic run-to-fixed-point implementations where applicable.

Actual production bottlenecks are expected to be:
- chain/index latency;
- participant consent;
- ERP synchronization;
- off-chain settlement confirmation.

## 15. Privacy

Default discovery should operate on:
- public/minimally published obligation edges;
- local participant neighborhood.

Private ERP fields remain local.

A hosted global scanner may be offered only for participants who explicitly publish necessary metadata.

## 16. Failure cases

- stale index → revalidate / reject before lock;
- obligation quantity changed → recompute proposal;
- policy changed → invalidate previous auto-accept;
- participant deactivated → reject new step;
- lock conflict → recompute;
- exchange equivalence expired → manual/new quote;
- AI unavailable → deterministic clearing continues.

## 17. Observability

Metrics:
- candidate paths found;
- eligible paths;
- auto-accepted/manual/rejected;
- proposal-to-settlement conversion;
- estimated vs successfully settled value;
- stale snapshot rejection;
- lock conflicts;
- algorithm runtime;
- AI ranking latency/cost if enabled.

## 18. Tests

- open A→B→C path;
- no cycle required;
- bilateral special case;
- path inside a cycle;
- fixed-point deterministic repeatability;
- tie-break determinism;
- partial quantities;
- incompatible currency rejection;
- compatible same-resource goods;
- unlike-resource no-equivalence rejection;
- policy auto-accept;
- policy manual;
- policy reject;
- stale state rejection;
- lock conflict;
- AI disabled path works identically;
- quality constraint rejects otherwise structural path;
- positive attribute stake makes path eligible only when participant policy explicitly permits it;
- negative stake can make a path ineligible under policy;
- stake never mutates observed quality;
- claim on `delivery.on_time` cannot satisfy unrelated `product.conformity` requirement.

## 19. Acceptance criteria

- Service discovers clearing on an acyclic A→B→C graph.
- Same input snapshot/policies produces same deterministic proposal.
- No LLM is required for settlement correctness.
- Proposal contains enough data to explain before/after obligations.
- Execution preparation revalidates TRD-03 state.
- Separate cycle optimizer is absent from MVP dependency chain.
- Clearing can use the multidimensional `R/Q/S` state without collapsing it to a single global reputation score.
