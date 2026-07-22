# THR-110 S1-06 implementation verification

Implementation heads:

- ThorChainKit: `3f492c8c7f334d69ce0cacb14157ba9846f59c69`
- MarketKit: `2c327452237cfbbdc4d87bcd5dd417d1da46a61e`
- Unstoppable: `1a531bbb43c81902fe4d573ded39ec047ae5437c`

Passed checks:

- ThorChainKit iOS package build with the reviewed manifest and no target-level
  unsafe flags: `xcodebuild -scheme ThorChainKit -destination 'generic/platform=iOS' -quiet CODE_SIGNING_ALLOWED=NO build`.
- WalletCore package resolution fetched the exact ThorChainKit and MarketKit
  revisions; Xcode package resolution completed with ThorChainKit at
  `3f492c8c7f334d69ce0cacb14157ba9846f59c69`, MarketKit at
  `2c327452237cfbbdc4d87bcd5dd417d1da46a61e`, and GRDB at 6.29.3.
- Project-file lint and whitespace validation passed:
  `plutil -lint Unstoppable/Unstoppable.xcodeproj/project.pbxproj` and
  `git diff --check`.

Unrun or environment-blocked checks:

- MarketKit focused XCTest compilation was not reached because the unchanged
  package graph rejects its macOS 10.13 declaration with ObjectMapper's macOS
  12 requirement.
- The Unstoppable Development build was not reached because the clean approved
  checkout does not contain the locally included `Config.xcconfig` required by
  `App-Dev.xcconfig` and `Widget-Dev.xcconfig`.
- The warnings-as-errors package invocation was not usable because dependency
  targets combine `-warnings-as-errors` with `-suppress-warnings`; the normal
  ThorChainKit iOS build passed.

No simulator, Maestro, UI, import, discovery, relaunch, explorer, signer,
history, swap, or custom-node work was performed.
