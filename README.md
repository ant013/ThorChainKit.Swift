# ThorChainKit.Swift

`ThorChainKit` is a standalone Swift package for native THORChain support in
Unstoppable Wallet iOS. The repository is currently a documentation-only seed:
implementation starts with the approved Sprint 1 slices and follows the
repository gates in [`AGENTS.md`](AGENTS.md).

## Project map

- [`ROADMAP.md`](ROADMAP.md) — authoritative roadmap used by the dormant
  Paperclip CEO walker.
- [`docs/roadmap/`](docs/roadmap/) — sprint plans and vertical acceptance
  outcomes.
- [`docs/specs/`](docs/specs/) — detailed, reviewable slice specifications.
- [`docs/research/`](docs/research/) — protocol, architecture analog, Vultisig,
  test-app, and orchestration research.
- [`docs/reports/`](docs/reports/) — adversarial review and Gimle reliability
  reports.

## Current boundary

The seed intentionally contains no `Package.swift`, `Sources/`, `Tests/`,
`iOS Example/`, or `.maestro/`. Those areas are introduced by their approved
roadmap slices. Maestro acceptance is scoped only to the kit's future
`iOS Example`; it is never applied to Unstoppable Wallet.

Native RUNE read, send, history, THOR actions, assets, and provider reliability
belong to v1. An internal native THORChain swap implementation is reserved for
v2; the existing multichain swap provider remains separate until that slice.
