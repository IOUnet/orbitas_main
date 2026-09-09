# The Graph / MCP skill source basis — 2026-09-09

Primary upstream references used to build this skill:

- The Graph: Subgraph Manifest documentation (`specVersion` 1.3.0 current at baseline time).
- The Graph: AssemblyScript API/type-conversion documentation.
- The Graph: schema/query best practices, immutable entities, Bytes IDs, pruning, query pagination and `_meta` health.
- The Graph packages: `@graphprotocol/graph-cli` 0.98.1 and `@graphprotocol/graph-ts` 0.38.2 baseline.
- Model Context Protocol official TypeScript SDK v2 documentation, implementing MCP 2026-07-28.
- MCP npm packages: `@modelcontextprotocol/server` 2.0.0 and `@modelcontextprotocol/node` 2.0.0.

Important type rule: Ethereum uint32..uint256 and int64..int256 map to Graph `BigInt`; smaller integer ABI types map to AssemblyScript `i32`.
