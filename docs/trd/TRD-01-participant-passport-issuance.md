# TRD-01 — Participant Passport Issuance Service

**Status:** Draft for approval  
**Depends on:** none  
**Consumed by:** TRD-02, ERP connectors  
**MVP principle:** self-service; no admin approval; company data + website are self-declared

## 1. Objective

Provide the simplest possible self-service onboarding flow that creates an Orbitas participant identity and an on-chain participant passport.

The MVP MUST allow a company representative to:
1. connect a wallet/controller;
2. enter company information;
3. enter the company website;
4. sign the registration intent;
5. receive a `passportId`;
6. use that passport to issue obligations.

No KYB, administrator approval, domain ownership proof, reputation score, DID, VC, SBT reputation or external registry verification is required for issuance.

## 2. Non-goals

- legal verification of the company;
- tax-number verification;
- beneficial-owner verification;
- sanctions/KYB screening;
- domain verification;
- reputation scoring;
- employee identity management;
- multi-jurisdiction legal qualification.

The system MUST label the MVP profile as `SELF_DECLARED`.

## 3. Component boundary

```text
User / ERP Plugin
       │
       ▼
Passport Issuance API / UI
       │
       ├── validate input
       ├── normalize website
       ├── build profile JSON
       ├── store profile off-chain/IPFS
       ├── request typed signature
       ▼
Passport Smart Contract (TRD-02)
       │
       ▼
passportId
```

The issuance service is a convenience/orchestration layer. The passport contract remains canonical for passport existence and controller state.

## 4. Minimal participant profile

### 4.1 Required

```json
{
  "companyName": "Example LLC",
  "website": "https://example.com"
}
```

### 4.2 Optional extensible fields

```json
{
  "legalName": "Example LLC",
  "tradeName": "Example",
  "countryCode": "MX",
  "registrationNumber": null,
  "taxId": null,
  "contactEmail": null,
  "description": null
}
```

Optional fields MUST NOT become issuance blockers in MVP.

### 4.3 System fields

```json
{
  "schemaVersion": "1.0",
  "verificationLevel": "SELF_DECLARED",
  "createdAt": "...",
  "updatedAt": "...",
  "controller": "0x...",
  "websiteNormalized": "https://example.com"
}
```

## 5. Website normalization

The service MUST:
- require `https://` or normalize to HTTPS when unambiguous;
- lowercase hostname;
- remove URL fragment;
- preserve meaningful path only if the user explicitly enters one;
- reject non-HTTP(S) schemes;
- cap URL length;
- NOT claim domain ownership verification.

Examples:

`EXAMPLE.com` → `https://example.com`

`https://example.com/#about` → `https://example.com/`

## 6. Registration workflow

### 6.1 Direct wallet mode

1. Client calls `POST /v1/passports/prepare`.
2. Service validates and normalizes input.
3. Service creates canonical profile JSON.
4. Profile is persisted to IPFS/off-chain storage.
5. Service returns:
   - `profileHash`;
   - `profileURI`;
   - typed registration payload.
6. User signs/submits to passport contract.
7. Service waits for `PassportRegistered`.
8. Service returns `passportId`.

### 6.2 Relayed mode

A hosted Orbitas node MAY submit the transaction if the user signs a typed intent.

Requirements:
- relayer cannot modify signed profile hash;
- signature has nonce and expiry;
- replay protection is mandatory;
- relayer does not become passport owner/controller.

## 7. Public API

### `POST /v1/passports/prepare`

Request:

```json
{
  "controller": "0x...",
  "companyName": "Example LLC",
  "website": "https://example.com",
  "optionalProfile": {
    "countryCode": "MX"
  }
}
```

Response:

```json
{
  "profileHash": "0x...",
  "profileURI": "ipfs://...",
  "normalizedProfile": {},
  "typedData": {},
  "expiresAt": "..."
}
```

### `POST /v1/passports/relay`

Request:
- prepared registration payload;
- user signature;
- idempotency key.

Response:
- transaction hash;
- pending registration ID.

### `GET /v1/passports/{passportId}`

Returns read projection from indexer/contract:
- controller;
- company name;
- website;
- metadata URI/hash;
- status;
- self-declared verification marker.

## 8. Duplicate policy

MVP policy:
- one active passport per controller wallet;
- company names and websites are NOT globally unique;
- duplicate company profiles are possible because identity is self-declared.

The UI SHOULD warn if another public passport uses the same website, but MUST NOT block issuance solely on that basis.

Future verification may resolve duplicates; not MVP.

## 9. Controller rotation

The issuance UI MUST expose a controller-rotation flow provided by TRD-02.

Passport identity stays the same; controller wallet changes.

Controller rotation MUST require authorization by the current controller in MVP.

Lost-key recovery is not solved in this TRD.

## 10. Security requirements

- Never store raw private keys.
- Validate and canonicalize profile JSON before hashing.
- Pin/persist profile content before submitting the on-chain hash when possible.
- Use nonce + expiry for relayed signatures.
- Rate-limit public prepare/relay endpoints.
- Validate wallet address format.
- Escape/sanitize all public profile strings.
- Website fetching is NOT required; therefore SSRF via website field must not occur.
- If future preview fetching is added, it must run in an isolated SSRF-safe fetcher.

## 11. Observability

Metrics:
- passport prepare attempts;
- wallet signature completion rate;
- chain submission success/failure;
- registration confirmation latency;
- duplicate-website warnings;
- IPFS/profile persistence failures.

Logs MUST include:
- request correlation ID;
- controller address;
- profile hash;
- tx hash;
- passportId after finality.

Do not log private keys or full sensitive optional profile data.

## 12. Tests

Required:
- happy-path direct registration;
- happy-path relayed registration;
- duplicate controller rejected;
- duplicate website allowed with warning;
- malformed website rejected;
- replayed signature rejected;
- expired signature rejected;
- profile hash mismatch rejected;
- IPFS failure does not create misleading completed state;
- controller rotation.

## 13. Acceptance criteria

- A user with a wallet can create a passport without an administrator.
- Required user input is no more than company name + website + wallet consent.
- Successful registration produces a stable `passportId`.
- Passport is visibly marked `SELF_DECLARED`.
- Passport can immediately be referenced by TRD-03 obligation issuance.
- No KYB dependency exists in the issuance path.

## 14. Open questions

- Whether `countryCode` should become mandatory before the first legally binding pilot.
- Whether a hosted relayer is enabled by default or users pay/submit gas themselves.
- Lost-key recovery mechanism is post-MVP unless explicitly prioritized.
