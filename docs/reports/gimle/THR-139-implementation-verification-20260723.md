# THR-139 implementation verification

- Verified ThorChainKit implementation HEAD: `d29e21591b73712903756a936559fa736ebbfc75`
- Verified Unstoppable substrate HEAD: `8a63bfda028dd8543115b26dd777235a53304311`
- Unstoppable delivery boundary: local, unstaged working-tree changes only; no retained feature branch, push, pull request, or merge
- Test host: local MacBook, Xcode iOS 26.2 runtime, iPhone 17 Pro simulator `0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`
- CI usage: none; repository policy keeps hosted Actions build-only

## Deterministic verification

- `Scripts/verify-s1-02.sh`: PASS
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES Scripts/verify-s1-03.sh`: PASS; derivation 5/5, codec 9/9, full suite 56/56
- `Scripts/verify-s1-04.sh`: PASS; 83/83 plus public-symbol, script-mode, and build-only Actions policy gates
- Unstoppable `Development` scheme preflight and verifier self-tests: PASS
- Unstoppable `AppTests/ThorChainKitManagerTests`: PASS, 12/12, zero failed or skipped tests on the pinned simulator
- Unstoppable `Development` `Debug-Dev` simulator build with automatic package resolution disabled and code signing disabled: BUILD SUCCEEDED
- Provider matrix: exactly Rorcual, IBS, and Keplr; all five non-identity REST permutations and all five non-identity RPC permutations fail closed before factory access
- The two previously proposed MultiSwap source changes were removed as out of scope

## Local-input binding

- Before manifest SHA-256: `2c3904dd64e5c8ddb39e047fbee476e577ced482fcb701c4cd1d1d62d58ac5b6`
- After manifest SHA-256: `9370605a626ec34f4692ad482cb335f27e321297a72eb0d03f989016933ce27a`
- Delta manifest SHA-256: `8688ac8121b1c4e2a93e1daf650df707761a41545dcb82a6dea6614dfb825aaa`
- Both manifests bind the same Unstoppable HEAD. The five-record delta contains three approved provider-pool/test changes and the removal of the two rejected MultiSwap source changes.
- All 34 in-scope implementation paths were independently compared byte-for-byte with the reviewed correction tree.
- The pre-existing `Unstoppable/Tests/Modules/MultiSwap/SwapExecutableTests.swift` edit remains separate and untouched.

## Three-family mainnet smoke

Each evidence file binds exact ThorChainKit HEAD `d29e21591b73712903756a936559fa736ebbfc75`, chain `thorchain-1`, positive and closely matching Cosmos/Comet heights, existing-account RUNE equality, and the audited absent-account empty state.

- Rorcual: PASS; accepted height `27128330`; RUNE `1079580`; evidence SHA-256 `db8390695fdcfd33fa4cd78dcd7b1bedf16baf7442113ea3706aae7032c8ff3e`
- IBS: PASS; accepted height `27128167`; RUNE `1079580`; evidence SHA-256 `2339b25418bfc5fb3e614531b785abb68deb897666e306f6b20f6ef124803e5c`
- Keplr: PASS; accepted height `27128177`; RUNE `1079580`; evidence SHA-256 `6d014a9fb77db02159123c282b49cc4d043af2956fb729c0908a1386cb622203`
- All live-test launchd variables were verified unset after the runs.

Rorcual timed out during three earlier attempts and then passed without a production-code change after its REST/RPC endpoints recovered. The failed attempts remain diagnostic evidence of external provider instability, not acceptance evidence.

## Provenance and residual boundary

- ThorChainKit local HEAD equals the pushed branch head.
- No commit contains a `Co-authored-by:` trailer.
- Exactly two intentional untracked Gimle reports remain byte-for-byte preserved.
- Gimle trust remains RED because the indexed EvmKit snippet was stale and semantic-search coverage was incomplete. All load-bearing implementation decisions were independently verified with the current trees through Serena, targeted ripgrep, and Git.
- Final Unstoppable commit creation remains an explicit operator-controlled action outside this slice.
