# Development Status

## Implemented in bootstrap

- ParticipantPassport contract
- MultidimensionalObligation contract (`T=(R,Q,S)` protocol hooks)
- BilateralExchange contract
- MultilateralClearing path contract
- Foundry configuration + deployment script
- Unit tests for passport/obligation plus bilateral and open-path settlement; stateful obligation invariant test
- The Graph schema/manifest/mappings
- MCP v2 read-only server over indexer
- Solidity and The Graph development skills
- GitHub Actions skeletons

## Not yet validated

This environment did not have the project Foundry/npm dependencies installed and outbound package installation was unavailable, so a full compile/test run could not be completed here. A system `tsc` exists, but MCP/Subgraph package types are unavailable until dependencies are installed. CI is configured to perform compilation and tests once the repository is hosted with network-enabled GitHub Actions.

Before deployment:

1. install pinned dependencies;
2. run `forge fmt`, `forge build`, `forge test`;
3. fix any ABI/codegen mismatches;
4. regenerate ABI JSON from compiled contracts;
5. fill deployment addresses/start blocks in the Subgraph manifest;
6. run `graph codegen && graph build`;
7. run security static analysis and invariant campaigns;
8. perform external review before production funds/obligations.

## GitHub repository blocker

The connected GitHub tool can create files/branches/issues in existing repositories, but does not expose repository-creation capability. `IOUnet/orbitas_main` did not exist when this bootstrap was prepared. Create the empty repository in the IOUnet organization (or enable a GitHub action that supports repository creation), then the prepared tree can be pushed immediately.


## Local git baseline

The bootstrap is initialized as a local `main` Git repository. The initial implementation commit was created locally; it is ready to push once `IOUnet/orbitas_main` exists.
