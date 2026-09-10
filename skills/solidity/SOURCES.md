# Solidity skill source basis — 2026-09-09

Primary upstream references used to build the Orbitas Solidity skill:

- Solidity documentation: Security Considerations, NatSpec, SMTChecker.
- Solidity compiler binary release index: 0.8.36 (`commit.8a079791`) is the stable release pinned by this repository.
- OpenZeppelin Contracts documentation: AccessControl/AccessManager, cryptography/EIP-712, security utilities.
- OpenZeppelin Contracts Security Center: 5.6.1 security baseline at the time of research.
- OpenZeppelin GitHub releases: later tags must be reconciled with the Security Center before upgrading.
- Foundry Book: fuzz testing and stateful invariant testing.
- forge-std GitHub releases: v1.16.1 release baseline.
- OWASP Smart Contract Security Verification / Smart Contract Security guidance.

Upgrade rule: re-check upstream release/security pages before changing compiler or security-library pins.
