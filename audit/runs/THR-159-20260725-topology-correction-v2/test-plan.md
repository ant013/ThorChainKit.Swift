# THR-159 topology correction test plan

This test plan is bound to correction revision `THR-159-TOPOLOGY-V2-R2`,
baseline architecture revision 10 commit
`518835315a65996b9321665213adb0516503df65`, and S2-06 spec commit
`29611561f86765ee2ab9249a2de65a0989cc1626` (spec blob
`c0d862e9b861a117327864b60c534e539f9d5a8a`). Use a fresh output root for the
exact HEAD and simulator UDID; do not reuse default DerivedData.

1. Static manifest contract: assert the root manifest contains the pinned
   HdWalletKit revision, `ThorChainExampleLiveSupport` dynamic product, `LiveSupport`
   target path/dependencies, and no package-level library API drift.
2. Xcode graph contract: assert the project has one local package reference,
   no direct remote HdWalletKit reference, Live links both local products, and
   Fixture links only native FixtureSupport.
3. Reproduction/build gate: with `HEAD=$(git rev-parse HEAD)`,
   `UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`, and
   `OUT="artifacts/s2-06/acceptance/$HEAD/$UDID"`, run these exact commands
   from the repository root:

   ```sh
   mkdir -p "$OUT"
   FIXTURE_DERIVED="$OUT/fixture-derived"
   LIVE_DERIVED="$OUT/live-derived"
   xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'ThorChainExampleFixture' -configuration Debug -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$FIXTURE_DERIVED" CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$OUT/fixture-debug.log"
   test "${PIPESTATUS[0]}" -eq 0
   rg -q '^\*\* BUILD SUCCEEDED \*\*$' "$OUT/fixture-debug.log"
   test -d "$FIXTURE_DERIVED/Build/Products/Debug-iphonesimulator/ThorChainExampleFixture.app"
   xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'ThorChainExampleLive' -configuration Release -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$LIVE_DERIVED" CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$OUT/live-release.log"
   test "${PIPESTATUS[0]}" -eq 0
   rg -q '^\*\* BUILD SUCCEEDED \*\*$' "$OUT/live-release.log"
   test -d "$LIVE_DERIVED/Build/Products/Release-iphonesimulator/ThorChainExampleLive.app"
   ```

   The original missing Crypto package-product binary is reproduced by the
   pre-change log and must be absent after both commands. Persist the two logs,
   exact HEAD, UDID, schemes, configurations, and resolved app paths.
4. Release gate: invoke the release audit against the exact Live artifact from
   step 3, not a default build location:

   ```sh
   Scripts/audit-example-release-binary.sh --scheme ThorChainExampleLive --configuration Release --destination "platform=iOS Simulator,id=$UDID" --derived-data-path "$LIVE_DERIVED" --app-path "$LIVE_DERIVED/Build/Products/Release-iphonesimulator/ThorChainExampleLive.app" --expected-head "$HEAD" --expected-udid "$UDID"
   ```

   The audit must fail closed when the app path, HEAD, or UDID does not match;
   reject `FixtureSupport.framework`/`ThorChainExampleFixtureSupport`; and scan
   the main executable plus every executable binary under the app bundle's
   embedded frameworks for `FixtureScenario`, `FixtureTransport`,
   `FixtureSigner`, and fixture product symbols. Unresolved artifacts or any
   forbidden symbol fail the gate.
5. QA gate: after both app artifacts exist, run exactly:

   ```sh
   THORCHAIN_SIMULATOR_UDID="$UDID" Scripts/run-maestro.sh s2-06
   ```

   Require exit zero, exactly five flows, JUnit `tests=5`, `failures=0`,
   `errors=0`, `skipped=0`, and evidence under the exact-head/UDID artifact
   directory emitted by the runner. Then perform the controlled LIVE read-only
   observation.
