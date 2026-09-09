# TRD-02 — Participant Passport Smart Contract

**Status:** Draft for approval  
**Depends on:** TRD-01  
**Consumed by:** TRD-03, TRD-04, ERP connectors  
**Contract role:** canonical on-chain identity/controller registry for Orbitas participants

## 1. Objective

Provide a permissionless, self-registration smart contract that assigns a stable `passportId` to an Orbitas participant.

MVP requirements:
- no administrator approval to register;
- non-transferable economic identity;
- controller wallet can be rotated by the current controller;
- metadata is updateable by the participant;
- company profile is self-declared;
- operators may be authorized for narrowly scoped protocol actions;
- contract emits complete indexing events.

## 2. Recommended contract shape

Use one shared registry contract:

`ParticipantPassportRegistry`

Do NOT deploy one contract per company.

A custom registry is preferred over forcing ERC-721 semantics. Optional ERC-721/SBT compatibility may be added later, but transferability MUST NOT define participant identity.

## 3. Data model

```solidity
enum PassportStatus {
    NONE,
    ACTIVE,
    DEACTIVATED
}

struct Passport {
    address controller;
    bytes32 metadataHash;
    string metadataURI;
    PassportStatus status;
    uint64 createdAt;
    uint64 updatedAt;
}
```

Mappings:

```solidity
mapping(uint256 => Passport) passports;
mapping(address => uint256) passportOfController;
mapping(uint256 => mapping(address => uint256)) operatorPermissions;
```

`operatorPermissions` is a bitmask.

Suggested permission bits:

```text
1 << 0  ISSUE_OBLIGATION
1 << 1  UPDATE_OBLIGATION_METADATA
1 << 2  PROPOSE_SETTLEMENT
1 << 3  CONFIRM_SETTLEMENT
```

The exact permission split MAY be reduced for MVP, but unlimited operator authority is discouraged.

## 4. Metadata

The contract stores:
- `metadataHash`;
- `metadataURI`.

Company name and website live in the referenced canonical profile JSON.

MVP MAY additionally emit selected public profile values in registration events for easier indexing, but the contract storage should avoid unnecessary strings.

## 5. Functions

### `registerPassport`

```solidity
function registerPassport(
    bytes32 metadataHash,
    string calldata metadataURI
) external returns (uint256 passportId);
```

Rules:
- caller must not already control an active passport;
- hash must be non-zero;
- URI must be non-empty;
- new passport status = ACTIVE.

### `registerPassportWithSig`

Optional relayer function:

```solidity
function registerPassportWithSig(
    address controller,
    bytes32 metadataHash,
    string calldata metadataURI,
    uint256 nonce,
    uint64 deadline,
    bytes calldata signature
) external returns (uint256 passportId);
```

Must verify typed signature, nonce, deadline.

### `updateMetadata`

Controller only.

### `rotateController`

Controller only in MVP.

Rules:
- new controller cannot already control another active passport;
- passportId remains stable;
- operator permissions SHOULD be revoked or explicitly re-confirmed after rotation.

### `setOperatorPermissions`

Controller only.

### `deactivatePassport`

Controller only.

Deactivation:
- blocks new obligation issuance;
- MUST NOT erase history;
- existing obligations remain readable and settleable according to TRD-03.

## 6. View functions

- `getPassport(passportId)`
- `passportOf(address controller)`
- `isActive(passportId)`
- `isAuthorized(passportId, operator, permission)`
- `nonceOf(controller)`

## 7. Events

```solidity
event PassportRegistered(
    uint256 indexed passportId,
    address indexed controller,
    bytes32 metadataHash,
    string metadataURI
);

event PassportMetadataUpdated(
    uint256 indexed passportId,
    bytes32 oldHash,
    bytes32 newHash,
    string newURI
);

event PassportControllerChanged(
    uint256 indexed passportId,
    address indexed oldController,
    address indexed newController
);

event PassportOperatorPermissionsChanged(
    uint256 indexed passportId,
    address indexed operator,
    uint256 permissions
);

event PassportDeactivated(
    uint256 indexed passportId
);
```

Events are part of the protocol API and MUST be treated as stable after mainnet/pilot release.

## 8. Access-control model

Admin/protocol governance MUST NOT:
- approve or reject ordinary passport issuance;
- edit participant company metadata;
- arbitrarily seize participant passport control.

A protocol-level pause MAY exist for emergency security.

If an upgradeable proxy is used, upgrade authority MUST be separated from participant business logic and documented in deployment config.

## 9. Invariants

1. One active passport per controller.
2. One controller per passport.
3. `passportId` never changes.
4. Deactivated passports are never deleted.
5. Metadata updates never alter historical events.
6. Operator permission never implies passport ownership.
7. Controller rotation cannot create duplicate active-controller mapping.
8. Registration is permissionless.

## 10. Integration with obligation contract

TRD-03 MUST validate:

```text
passportRegistry.isActive(issuerPassportId) == true
```

and either:
- `msg.sender == controller`, or
- `isAuthorized(passportId, msg.sender, ISSUE_OBLIGATION)`, or
- a valid typed intent from the controller.

A beneficiary passport may be active or, for an unclaimed external counterparty flow, `0` plus an external counterparty hash as defined in TRD-03.

## 11. Security

- Solidity compiler version pinned in implementation repo.
- Checks-effects-interactions discipline.
- Reentrancy guard only where external calls require it.
- Typed-signature domain separator includes chain ID and contract.
- Nonce increments on successful signed action.
- Deadline mandatory for relayed registration.
- URI length capped.
- Metadata hash required.
- Emergency pause cannot be used to rewrite past passport data.

## 12. Upgradeability

Recommended MVP choice: upgradeable deployment MAY be used because the protocol is early, but:
- storage layout must be tested;
- upgrades must be observable;
- upgrade admin must not have business-level passport editing authority;
- production pilot should use multisig/timelock policy appropriate to pilot risk.

If the team chooses immutable deployment, this section becomes deployment configuration rather than a requirement.

## 13. Tests

Unit/property tests:
- permissionless register;
- duplicate controller revert;
- metadata update authorization;
- controller rotation;
- duplicate new controller revert;
- operator permission set/revoke;
- deactivation;
- signed registration replay protection;
- wrong chain/domain signature rejection;
- invariants under fuzzing.

## 14. Acceptance criteria

- Contract can self-register participant with no admin transaction.
- TRD-01 can create and retrieve passport.
- TRD-03 can query issuer identity and authorization.
- TRD-04 can reconstruct passport state from events.
- No public transfer function can transfer a passport as an asset.
