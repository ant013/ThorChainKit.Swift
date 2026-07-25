# THR-159 topology spec delta — one local package root

Status: revised for targeted closure review; not approved for implementation.

## Spec identity binding

This correction retains architecture revision 10 as its baseline:
`518835315a65996b9321665213adb0516503df65`, canonical bundle digest
`a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc`.
The LiveSupport topology below is the later S2-06 spec revision at commit
`29611561f86765ee2ab9249a2de65a0989cc1626`, whose exact blob for
`docs/specs/sprint-02-native-send/S2-06-example-acceptance.md` is
`c0d862e9b861a117327864b60c534e539f9d5a8a`. This correction supersedes the
prior topology wording while preserving the architecture-revision-10 baseline;
fresh approval is required for this bound correction revision.

## Problem

At exact head `65589a48129789ad32f4c7a9a373ed3c5b523d0c`, the Example project
has the repository-owned `ThorChainKit` package root and a second direct
`HdWalletKit` package root. Fixture Debug reaches the HsCryptoKit product link
but Xcode emits the `Crypto_*_PackageProduct.framework` Info.plist without its
binary (`/tmp/thr159-65589a4-fixture-debug.log:1333-1346`).

## Minimal approved-design delta

1. Keep the `ThorChainKit` library target and public product unchanged. Add the
   existing pinned `HdWalletKit.Swift` revision
   `2fc0dbfc089f78a9804baafe8e1bc4aab69cbad1` to the root `Package.swift`.
2. Add a dynamic package product named `ThorChainExampleLiveSupport` backed by
   a target named `LiveSupport` at `iOS Example/LiveSupport`. Its direct target
   dependencies are `ThorChainKit`, pinned `HdWalletKit`, pinned `HsCryptoKit`,
   and the already-pinned `secp256k1` product. Do not move any source into the
   library target and do not change LiveSupport source/API behavior.
3. In the Xcode project, remove the native LiveSupport framework target and its
   app target dependency. Link the Live app to the local package products
   `ThorChainKit` and `ThorChainExampleLiveSupport`. Remove the direct remote
   `HdWalletKit` package reference/product dependency. Keep the native
   `ThorChainExampleFixtureSupport` target and its Fixture-only dependency
   unchanged.
4. Update only the target-graph audit assertions needed to express the new
   package-owned LiveSupport product and to reject a direct remote package root.
5. Make the release audit consume the exact Live Release app produced by the
   acceptance build, verify its exact HEAD and simulator UDID, reject the
   `FixtureSupport.framework` product, and scan every executable binary in the
   app bundle, including embedded framework binaries.

This preserves the approved boundary: LiveSupport remains Example-only and is
linked only by Live; FixtureSupport remains native, Fixture-only, and absent
from the library and Live product. The public ThorChainKit API, package pins,
secret loading, signer behavior, and runtime flows are unchanged.

## Rejected alternatives

- Re-adding a direct Xcode `HsCryptoKit` root: already removed and does not
  eliminate duplicate package-root composition.
- Keeping native LiveSupport while importing transitive package modules: it
  relies on undocumented transitive visibility and cannot preserve direct
  target dependencies under one root.
- Re-exporting HdWalletKit/HsCryptoKit from ThorChainKit: it leaks Example-only
  crypto ownership into the library target and violates the approved boundary.
- Copying or vendoring crypto sources: changes pins and exceeds this slice.

## Required checks before closure

- Manifest/graph assertions prove one local package root, the exact HdWalletKit
  revision, a dynamic LiveSupport product, and no direct remote HdWalletKit
  reference.
- Fixture Debug and Live Release exact-destination `xcodebuild` commands pass.
- Live Release binary audit is bound to that build's exact app/DerivedData and
  HEAD/UDID, resolves every executable in the app bundle, rejects
  `FixtureSupport.framework`, and finds no fixture symbols in any scanned
  binary.
- QA runs the guarded five-flow Maestro suite and controlled LIVE observation;
  no build, artifact, release, or Maestro claim is inferred from static checks.
