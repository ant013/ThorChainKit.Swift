# SwiftUI + Combine UI Boundary

**Status:** approved on 2026-07-20; normative documentation synchronized by this branch.
**Applies to:** the ThorChainKit product documentation, its `iOS Example`, and all future roadmap slices.

## Goal

Make the repository's UI policy unambiguous: ThorChainKit's library target is UI-agnostic and exposes state through Combine, while the repository-owned `iOS Example` is implemented only with SwiftUI and Combine. New or migrated repository-owned code must not import UIKit or introduce UIKit lifecycle/view-controller types.

## Assumptions

- The ThorChainKit library remains usable without a UI framework. `Sources/ThorChainKit` may use Foundation and Combine where required, but imports neither SwiftUI nor UIKit.
- SwiftUI belongs only to the `iOS Example` presentation layer. The Example observes the kit's Combine publishers without adding a second state owner.
- Removing the UIKit application lifecycle requires the SwiftUI `App` lifecycle. The Example deployment target therefore becomes iOS 14 or later, while the library's existing iOS 13 floor remains unchanged unless a separate approved task changes it.
- The policy applies to repository-owned product and Example code. Historical research/reliability reports and pinned external reference sources may still mention or contain UIKit when describing evidence; those mentions are not implementation permission.
- Unstoppable Wallet remains a separate repository. Its integration constraints are recorded here only where a ThorChainKit roadmap/spec handoff depends on them.

## Scope

Update the normative documentation so that every relevant roadmap, slice spec, test plan, and execution plan agrees on the following boundary:

1. `Sources/ThorChainKit/**`: Foundation/Combine domain and lifecycle code; no UIKit and no SwiftUI.
2. `iOS Example/**`: SwiftUI views and SwiftUI `App` lifecycle, with Combine-backed observation; no UIKit imports, `UIApplicationDelegate`, `UIWindow`, `UIViewController`, or representable wrappers around UIKit.
3. Maestro remains scoped to the SwiftUI `iOS Example` only.
4. Future UI-bearing slices extend the existing SwiftUI Example rather than adding UIKit screens/controllers.
5. Verification includes a fail-closed repository-owned source scan for UIKit imports and UIKit lifecycle/view-controller types.

Affected documentation areas:

- `AGENTS.md` — durable repository engineering contract;
- `docs/roadmap/00-project-roadmap.md`;
- `docs/roadmap/sprint-01-foundation.md`;
- `docs/specs/sprint-01-foundation/README.md`;
- every Sprint 1 slice spec or test plan that defines Example/Combine/UI behavior;
- `docs/superpowers/plans/2026-07-17-THR-12-s1-01-package-public-api.md`;
- `docs/research/kit-example-apps-and-ui-acceptance.md`, only to prevent its UIKit-base wording from being mistaken for current policy.

## Out of Scope

- Migrating the already merged UIKit-based Example source in this documentation-only task.
- Changing ThorChainKit's iOS 13 library deployment floor.
- Changing Unstoppable Wallet source or its Rx integration boundary.
- Rewriting historical Vultisig or Gimle evidence reports.
- Adding new Example functionality beyond recording the required SwiftUI migration and future UI constraints.

## Required Documentation Changes

### Repository contract

Add a durable platform rule stating that repository-owned production/Example code cannot import UIKit. Clarify that "SwiftUI + Combine" does not mean importing SwiftUI into the library target: the core remains UI-agnostic and the Example owns SwiftUI.

### Roadmap

- Record the SwiftUI/Combine boundary in the project-wide architecture rules and Definition of Done.
- Add a bounded corrective item for replacing the existing S1-01 UIKit Example before further Example UI slices build on it.
- Require each Example acceptance step to prove SwiftUI lifecycle/build plus absence of UIKit.
- Preserve the rule that Maestro runs only against the ThorChainKit Example.

### Sprint specs and plan

- Replace the S1-01 proposed tree's `AppDelegate.swift` and controller-centric wording with a SwiftUI `App`, views, and observable presentation model.
- Replace the TronKit UIKit-base decision with a topology-only reuse decision: workspace/package/scheme structure may be retained, but UIKit lifecycle and controllers are rejected.
- State that the library import allowlist permits Combine but rejects both UIKit and SwiftUI; the Example import allowlist permits SwiftUI and Combine but rejects UIKit.
- Require future address, sync, send, and acceptance screens to extend the SwiftUI shell.
- Keep the S1-06 Combine-to-Rx host bridge unchanged; it is an integration boundary and does not authorize UIKit in this repository.

### Existing implementation drift

Documentation must report rather than conceal the current mismatch:

- `iOS Example/Sources/AppDelegate.swift` imports UIKit and owns `UIWindow`;
- `DiagnosticsController.swift` and `MainController.swift` are UIKit controllers;
- the current Example deployment target is iOS 13.

The roadmap must make migration of those files a prerequisite for the next Example UI feature. Historical S1-01 completion evidence remains historically accurate and is not rewritten as if the SwiftUI migration had already shipped.

## Acceptance Criteria

- All normative files under `docs/roadmap/` and `docs/specs/` state or inherit the same UI boundary without contradictory UIKit-base guidance.
- The execution plan and Example research note no longer recommend a UIKit diagnostics application or future UIKit-base migration.
- The library and Example boundaries are distinguished explicitly: Combine is allowed in the library; SwiftUI is limited to the Example; UIKit is prohibited in both.
- The roadmap contains an explicit, testable migration item for the already merged UIKit Example and does not claim that migration is complete.
- The Example migration acceptance requires a SwiftUI `App` lifecycle, iOS 14-or-later Example target, unchanged library iOS 13 floor, green build/Maestro flow, and no repository-owned UIKit symbols/imports.
- Historical reports remain unchanged except where a separate approved correction is required.
- No source, test, project, or workflow file is changed in this documentation-only task.

## Verification Plan

```text
rg -n "UIKit|AppDelegate|UIApplicationDelegate|UIWindow|UIViewController" \
  AGENTS.md docs/roadmap docs/specs docs/superpowers/plans \
  docs/research/kit-example-apps-and-ui-acceptance.md

rg -n "^import UIKit|UIApplicationDelegate|UIWindow|UIViewController" \
  Sources/ThorChainKit "iOS Example/Sources"

rg -n "SwiftUI|Combine" AGENTS.md docs/roadmap docs/specs
git diff --check
```

The first and third checks are reviewed for consistent normative wording. The second check is expected to identify the existing Example migration debt until the separately approved source migration lands; it must return no matches after that migration.

## Open Questions

- None for the documentation boundary. The exact SwiftUI view/model filenames and whether the Example target uses iOS 14 or a higher already-supported floor belong to the later source-migration spec; iOS 14 is the minimum acceptable floor for a UIKit-free SwiftUI `App` lifecycle.
