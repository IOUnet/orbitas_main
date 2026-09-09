---
name: orbitas-solidity-development
version: "1.0.0"
description: Secure Solidity development rules for Orbitas passport, multidimensional obligations, bilateral exchange and multilateral clearing contracts.
license: Internal project guidance; source references retain their own licenses.
---

# Orbitas Solidity Development Skill

Use this skill whenever creating, changing, reviewing, testing or deploying Solidity/EVM contracts in Orbitas.

## 1. Current baseline

Repository baseline at creation time:

- Solidity: **0.8.36 stable**; production source files use exact pragma `pragma solidity 0.8.36;` for reproducibility.
- OpenZeppelin Contracts: pin an **audited tagged release**. Baseline: **v5.6.1**. GitHub also has a v5.7.0 release, but the OpenZeppelin Security Center still identifies 5.6.1 as the current security baseline; do not upgrade merely because a newer tag exists.
- Foundry + Forge Std: use tagged releases; baseline Forge Std **v1.16.1** (latest published release observed at baseline time; unreleased/master version strings are not sufficient for production pinning).
- Never depend on OpenZeppelin `master`/development branches for production.

Before upgrading compiler or security libraries, review release notes and storage/API compatibility.

## 2. Dependency rule

Use published/vetted OpenZeppelin contracts as installed dependencies. Do not copy-paste or locally modify OpenZeppelin security-critical source unless there is an explicit, reviewed reason.

Pin exact tags/commits in CI and deployment reproducibility files.

## 3. Contract architecture

Prefer small, modular contracts with narrow responsibilities:

- identity/passport;
- obligation state;
- quality/guarantee extension;
- bilateral settlement;
- multilateral path settlement.

Avoid monolithic contracts and unbounded on-chain graph algorithms.

## 4. Access control

- Use least privilege.
- Prefer role-based access (`AccessControl`/`AccessManager`) when multiple privileged capabilities exist.
- Separate protocol administration from participant business authority.
- Participant registration must remain permissionless where product requires it.
- Settlement roles may lock/finalize obligations but must not rewrite participant identity or source evidence.
- Never use `tx.origin` for authorization.
- Production admin roles should be assigned to multisig/timelocked governance appropriate to risk, not a developer EOA.

## 5. Signatures and relayers

For meta-transactions/consent:

- use EIP-712 typed data;
- include chain id and verifying contract in domain;
- include nonce/salt and deadline;
- make signed payload commit to every economic field that matters;
- reject replayed/expired signatures;
- check recovered signer against participant controller or scoped authorized operator.

## 6. Economic arithmetic

- Never use floating point.
- Store quantity/value as integer + explicit decimals/unit/currency.
- Bound inputs.
- Use Solidity 0.8 checked arithmetic by default.
- Use `unchecked` only after a proven bound and document the proof.
- Never aggregate collateral assets without an explicit valuation rule.

## 7. Checks / effects / interactions

Follow Checks-Effects-Interactions for functions making external calls.

Use `ReentrancyGuard` where external token/contract interactions occur or future hooks can re-enter. Do not assume `view` calls are economically harmless if they can observe inconsistent intermediate state.

## 8. External calls

- Treat all external calls as hostile/fallible.
- Check success/returned data.
- Use safe ERC-20 helpers where collateral tokens are later introduced.
- Avoid arbitrary `delegatecall`.
- Do not make state correctness depend on untrusted callbacks.
- Limit funds held by protocol contracts where possible.

## 9. Storage and state machines

Encode business invariants explicitly.

Orbitas obligation invariants include:

`settled + cancelled + locked <= total`

and:

- sourceRef cannot be duplicated by retries;
- settlement cannot consume more than its lock;
- final settlement cannot be reopened silently;
- stake cannot mutate factual properties;
- stake cannot rewrite observed quality history;
- claim/stake is scoped to the quality dimension it references.

Use explicit enums/state transitions and custom errors.

## 10. Events are protocol API

The indexer and AI tooling depend on contract events.

For every business-critical state transition:

- emit a stable event;
- index identifiers needed for filtering;
- include enough data to reconstruct state or fetch it deterministically;
- do not casually rename/reorder event ABI after deployment.

## 11. Metadata and evidence

Do not store full commercial documents on-chain.

Store hashes and URIs/references. Verify content hashes off-chain before trusting fetched metadata.

## 12. NatSpec and custom errors

All public/external ABI surfaces must have NatSpec.

Use custom errors instead of long revert strings for protocol errors.

Document:

- economic meaning;
- authorization;
- state preconditions;
- settlement effects;
- emitted events;
- security-sensitive assumptions.

## 13. Compiler discipline

- Use the latest reviewed stable compiler for new development; this repo pins 0.8.36 until deliberately upgraded.
- Treat compiler warnings as failures unless explicitly justified.
- Do not use experimental compiler features in production without review.
- Enable optimizer with pinned settings; record EVM target.
- Consider SMTChecker for invariant-heavy pure/state logic that can be expressed with `assert`/`require`.

## 14. Testing pyramid

Every contract change requires:

1. unit tests;
2. negative authorization/error-path tests;
3. fuzz tests for numeric boundaries;
4. stateful invariant tests for protocol invariants;
5. integration tests across the contract stack;
6. fork tests when external protocol integration exists.

Foundry invariant campaigns should use handlers, bounded inputs and `fail_on_revert=true` where the handler is intended to generate only valid actions. Persist/replay failing seeds in CI.

## 15. Mandatory Orbitas invariant campaigns

At minimum test:

- passport uniqueness/controller rotation;
- obligation sourceRef idempotency;
- `settled + cancelled + locked <= total` under arbitrary action sequences;
- no double settlement across bilateral and multilateral contracts;
- expired multilateral instructions release only their own locks;
- signatures cannot be replayed;
- quality claim on one key cannot satisfy another key;
- stake signal does not mutate observed quality.

## 16. Static/security analysis

CI should run, when toolchain is available:

- `forge fmt --check`
- `forge build`
- `forge test`
- `forge test` with fuzz/invariant CI profile
- `forge coverage`
- Slither static analysis
- OWASP Smart Contract Security Verification Standard / checklist review for release candidates

Do not treat a static analyzer as proof of correctness; triage findings against business invariants.

## 17. Upgradeability

Default MVP preference: **non-upgradeable contracts** unless an explicit architecture decision requires proxy upgradeability.

If upgradeability is introduced:

- use OpenZeppelin upgradeable patterns;
- validate storage layout;
- never jump across incompatible major storage layouts without migration design;
- separate upgrade authority from participant authority;
- add timelock/multisig and upgrade tests.

## 18. Gas versus safety

Safety and auditability outrank micro-optimizations.

Avoid:

- unbounded state-changing loops;
- global graph traversal on-chain;
- storage-heavy duplicated metadata;
- premature assembly/Yul.

Optimize only after profiling, tests and invariants remain intact.

## 19. Deployment discipline

Before deployment:

- pin compiler/dependencies;
- run full CI + static analysis;
- review role assignments;
- verify chain ID and addresses;
- deploy through reproducible script;
- verify source on explorer where supported;
- record deployment block for The Graph;
- grant settlement roles after contracts are deployed;
- revoke bootstrap/deployer privileges not required in production.

## 20. Reference basis

This skill is synthesized from current Solidity Security Considerations/NatSpec/SMTChecker guidance, OpenZeppelin Contracts 5.x security and access-control guidance, Foundry fuzz/invariant testing documentation, and OWASP Smart Contract Security Verification Standard material. Re-check current upstream guidance when doing a security-sensitive upgrade.
