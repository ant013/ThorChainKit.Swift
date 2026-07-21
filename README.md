# ThorChainKit.Swift

`ThorChainKit` is a standalone Swift package for native THORChain support in
Unstoppable Wallet iOS. Sprint 1 slices S1-01 through S1-03 are implemented;
S1-04 is the next active slice. Repository work follows the review and local
verification gates in [`AGENTS.md`](AGENTS.md).

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

The repository now contains the iOS 13 Swift package, tests, and the iOS 14+
SwiftUI `iOS Example` delivered by S1-01 through S1-03. All product tests,
mutants, Maestro, simulator, and live-network acceptance run on the shared
MacBook. GitHub Actions is manual build-only policy and remains disabled until
separately activated by the operator. Maestro is scoped only to the kit's
`iOS Example`; it is never applied to Unstoppable Wallet.

Native RUNE read, send, history, THOR actions, assets, and provider reliability
belong to v1. An internal native THORChain swap implementation is reserved for
v2; the existing multichain swap provider remains separate until that slice.
