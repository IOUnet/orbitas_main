# Orbitas Gateway v1

Canonical ERP-facing boundary between Orbitas connectors and protocol core.

## Responsibilities

- stable `/v1` HTTP API for Participant Passport linking/preparation;
- idempotent obligation publication from normalized ERP snapshots;
- indexed incoming/outgoing obligation reads;
- deterministic A→B→C candidate discovery;
- explicit signed participant consent;
- on-chain settlement-instruction execution and confirmation;
- replay-safe signed outbound webhooks.

The Gateway is a relayer/orchestrator, not an economic principal. It does not trust the indexer for final settlement authorization and revalidates canonical contract state before writes.

## Local sandbox

The root `make test-env` target starts the Gateway after contract/Subgraph deployment and runs the cross-ERP Odoo + 1C fixture scenario.

Local URL:

`http://127.0.0.1:3100`

Local bearer token:

`orbitas-local-token`

The committed local token and Anvil keys are test fixtures only.

## API

See [openapi.yaml](openapi.yaml).

### Signing

The Gateway never accepts participant private keys.

- Passport creation uses `POST /v1/passports/prepare` to return contract calldata for the participant to sign/send.
- Obligation publication is relayed only when the Gateway relayer has the Passport `ISSUE_OBLIGATION` operator permission.
- Multilateral clearing approvals are raw signatures over the on-chain `pathDigest`.
- Settlement confirmation signatures are over the on-chain `confirmationDigest`.

## Persistence

P0 stores links, idempotency responses, proposals, approvals, settlements, webhook subscriptions and delivery records in PostgreSQL under the `orbitas_gateway` schema.
