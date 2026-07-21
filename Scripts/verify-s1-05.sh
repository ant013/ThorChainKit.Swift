#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
base='d35770a0430eee921fa1fe91b2f8812a8c0535ff'
destination='id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17'
: "${S105_EXPECTED_HEAD:?S105_EXPECTED_HEAD must be a 40-character implementation head}"
[[ "$S105_EXPECTED_HEAD" =~ ^[0-9a-f]{40}$ ]] || { echo "FAIL S1-05 invalid expected head" >&2; exit 1; }
[[ "$(git rev-parse HEAD)" == "$S105_EXPECTED_HEAD" ]] || { echo "FAIL S1-05 HEAD mismatch" >&2; exit 1; }
[[ "$(git merge-base HEAD "$base")" == "$base" ]] || { echo "FAIL S1-05 base is not an ancestor" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "FAIL S1-05 implementation head has a dirty worktree" >&2; exit 1; }

allowed=(
    Package.swift Package.resolved
    Sources/ThorChainKit/Core/KitFactory.swift
    Sources/ThorChainKit/Core/Kit.swift
    Sources/ThorChainKit/Core/KitDependencies.swift
    Sources/ThorChainKit/Network/EndpointPool.swift
    Sources/ThorChainKit/State/StatePublishing.swift
    Sources/ThorChainKit/State/AccountStateManager.swift
    Sources/ThorChainKit/State/StateSnapshot.swift
    Sources/ThorChainKit/Storage/AccountStateStorage.swift
    Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift
    Sources/ThorChainKit/Storage/Migrations.swift
    Sources/ThorChainKit/Storage/StorageRecord.swift
    Sources/ThorChainKit/Sync/AccountSyncer.swift
    Sources/ThorChainKit/Sync/AccountSyncing.swift
    Sources/ThorChainKit/Sync/LifecycleCommandBridge.swift
    Sources/ThorChainKit/Sync/LifecycleGate.swift
    Sources/ThorChainKit/Sync/SyncGeneration.swift
    Sources/ThorChainKit/Sync/SyncSchedule.swift
    iOS\ Example/Sources/Configuration.swift
    iOS\ Example/Sources/Core/ExampleRuntime.swift
    iOS\ Example/Sources/Presentation/LifecycleViewModel.swift
    iOS\ Example/Sources/Views/DiagnosticsView.swift
    iOS\ Example/Sources/Views/LifecycleView.swift
    iOS\ Example/iOS\ Example.xcodeproj/project.pbxproj
    .maestro/flows/04-lifecycle-restart.yaml
    Scripts/run-s1-05-maestro.sh
    Scripts/test-s1-04-s1-05-isolation.sh
    Scripts/test-s1-05-dependency-floor.sh
    Scripts/test-s1-05-lifecycle-invariants.sh
    Scripts/verify-bigint-floor.sh
    Scripts/verify-s1-05.sh
    Tests/ThorChainKitTests/AccountStateStorageTests.swift
    Tests/ThorChainKitTests/AccountSyncerTests.swift
    Tests/ThorChainKitTests/EndpointPoolTests.swift
    Tests/ThorChainKitTests/KitLifecycleTests.swift
    Tests/ThorChainKitTests/LifecycleInvariantProbeTests.swift
    Tests/ThorChainKitTests/PublicApiTests.swift
    Tests/ThorChainKitTests/Fixtures/S1-05-public-symbols.txt
    Tests/ThorChainKitTests/Fixtures/S1-05-tests.txt
    docs/reports/gimle/THR-87-s1-05-gimle-reliability.md
    docs/specs/sprint-01-foundation/S1-05-rune-account-sync.md
    docs/superpowers/plans/2026-07-21-THR-87-s1-05-rune-account-sync.md
)
changed=$(git diff --name-only "$base..HEAD")
while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    allowed_match=false
    for candidate in "${allowed[@]}"; do
        if [[ "$path" == "$candidate" ]]; then allowed_match=true; break; fi
    done
    [[ "$allowed_match" == true ]] || { echo "FAIL S1-05 changed path outside allowlist: $path" >&2; exit 1; }
done <<< "$changed"
[[ -n "$changed" ]] || { echo "FAIL S1-05 no implementation changes are bound" >&2; exit 1; }
git diff --check "$base..HEAD"
cmp -s Tests/ThorChainKitTests/Fixtures/S1-04-public-symbols.txt Tests/ThorChainKitTests/Fixtures/S1-05-public-symbols.txt
! rg -n '(^|/)UIKit|mnemonic|seed phrase|private key' 'Sources/ThorChainKit' 'iOS Example/Sources'

Scripts/verify-s1-04.sh --source-only >/dev/null
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 Scripts/verify-s1-04.sh --fixtures-only >/dev/null
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 Scripts/verify-s1-03.sh --fixtures-only >/dev/null

selectors=(
    AccountSyncerTests/testRefreshUsesOneCompleteReadAndPublishesOneSnapshot
    AccountSyncerTests/testStopRacingSaveEstablishesGenerationAndPublicationBarrier
    AccountSyncerTests/testStopControlFailureFailsClosedAndDrainsOldGeneration
    AccountSyncerTests/testReentrantStopDoesNotWaitOnFacadeDispatcher
    AccountStateStorageTests/testLoadUsesOneConsistentReadSnapshot
    AccountStateStorageTests/testInvalidFreshRecordIsRejectedBeforeSave
    AccountStateStorageTests/testStorageSaveFailurePublishesStorageUnavailableWithoutSynced
    KitLifecycleTests/testLastBlockHeightMatchesAcceptedHeightBeforePublisherDelivery
    KitLifecycleTests/testRuneBalanceUsesExactRuneProjection
    KitLifecycleTests/testStopCompletionWaitsForSuccessAndControlFailureCancellation
    KitLifecycleTests/testCurrentGenerationFailureIngressPreservesCachedState
)
[[ ${#selectors[@]} -eq 11 ]] || { echo "FAIL S1-05 selector contract changed" >&2; exit 1; }

result_bundle=${S105_RESULT_BUNDLE:-artifacts/s1-05/Test.xcresult}
mkdir -p "$(dirname "$result_bundle")"
if [[ -e "$result_bundle" ]]; then find "$result_bundle" -depth -delete; fi
[[ ! -e "$result_bundle" ]] || { echo "FAIL S1-05 stale result bundle remains" >&2; exit 1; }
allowlist=$(mktemp)
trap 'find "$allowlist" -delete' EXIT
printf 'ThorChainKitTests.%s\n' "${selectors[@]}" >"$allowlist"

args=(xcodebuild test -scheme ThorChainKit -destination "$destination" -resultBundlePath "$result_bundle" SWIFT_SUPPRESS_WARNINGS=NO)
for selector in "${selectors[@]}"; do args+=(-only-testing:"ThorChainKitTests/$selector"); done
"${args[@]}" >/dev/null
[[ -d "$result_bundle" ]] || { echo "FAIL S1-05 result bundle is missing" >&2; exit 1; }
Scripts/verify-xcresult.sh S1-05 "$result_bundle" "$allowlist" >/dev/null

Scripts/test-s1-05-dependency-floor.sh >/dev/null
Scripts/test-s1-05-lifecycle-invariants.sh >/dev/null
Scripts/test-s1-04-s1-05-isolation.sh >/dev/null
S105_MAESTRO_RESULTS=build/s1-05-maestro-results \
S105_MAESTRO_DERIVED_DATA=build/s1-05-maestro-derived \
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 \
Scripts/run-s1-05-maestro.sh >/dev/null

echo "PASS S1-05 exact-head local verification"
