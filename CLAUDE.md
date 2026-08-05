# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

QuestKeeper is a **native iOS gamified to-do app** (SwiftUI + SwiftData) whose real purpose is a learning project: crossing OS boundaries (background time judgment, local-notification lifecycle, widgets, app lifecycle, 1st-party data stack) directly in native code instead of hiding behind a Flutter/RN bridge.
The gamification (deadline miss → the pixel hero dies) is the vehicle that pulls the learning curriculum along, not the end goal.

`BLUEPRINT.md` is the authoritative roadmap — read it before any feature work.
It defines the phases, success criteria, and the non-negotiable core principle below.
This file summarizes the parts that shape _how_ to write code here; BLUEPRINT owns _what_ to build and in _what order_.

**Current state:** the boilerplate template is gone — `Quest` (`@Model`) replaced `Item`, and `ContentView` is now the Phase 2 dungeon root, not template scaffolding.
BLUEPRINT's Phases 1–5 are implemented: the fact-only SwiftData model (`QuestKeeperShared/Quest.swift`), the pure derivation layer (`QuestKeeper/Derivation/`), the dungeon UI with completion/retry/daily-grave/edit flows (`QuestKeeper/Views/`), the local-notification lifecycle (`QuestKeeper/Notifications/`), and the WidgetKit App Group snapshot (`QuestKeeperShared/`, `QuestKeeperWidget/`).
Work past the BLUEPRINT roadmap has since added interactive widget completion, pixel art, retention measurement, an onboarding experiment, the daily-focus loop, and the recovery-loop prototype — `docs/specs/` runs to `015-recovery-loop-prototype.md`.
Extend the established per-role layer conventions; `docs/specs/` holds the per-phase contracts.

## Docs Layout

Additional docs live under `docs/` — `docs/notes/` (working notes), `docs/plans/` (implementation plans), `docs/specs/` (specifications).
The first spec is `docs/specs/001-project-setup.md` (Phase 0: platform scoping, Swift 6, boilerplate cleanup).

## Core Design Principle — "Persist facts only, derive state"

This is the architectural spine.
Every gamification rule must preserve it:

- **Persist**: only immutable raw facts — `task.deadline`, `task.completedAt`, `task.importance`.
- **Derive**: outcome, urgency, mob level, victory and daily-grave counts — all computed **against the current time at read time**, never stored.
- Deadline judgment is **state replay, not event-driven**: on app reopen, compare `lastOpened` against each task's `deadline` to retroactively reconstruct which heroes should have died in between.
- `urgency = f(time remaining until deadline)` — a derived, time-varying axis (turns the Eisenhower matrix into a live-moving one). `mobLevel = importance (stored) × urgency (derived)`.

Concrete guardrail: the quest `@Model` must never contain a derived-state field (`hp`, `isDead`, `mobLevel`, `urgency`).
If you're tempted to store one, it belongs in a pure derivation function instead.
This is about gamification state on `Quest`. The other `@Model`s in `QuestKeeperShared/` — `RetentionEvent`, `RetentionInstallation`, `ExperimentAssignment`, `DailyFocusSelection` — are append-only measurement records, not game state, and are deliberately outside the guard below.
The derivation entry point `HeroDerivation.state(quests:now:lastOpened:calendar:)` must stay a pure function — same inputs, same output (deterministic).

Whenever the quest persistence or snapshot types change, this guard must return nothing.
Its scope must cover **both** paths — `Quest` (`@Model`) lives in `QuestKeeperShared/`, so a guard pointed only at `QuestKeeper/Models/` scans no `@Model` at all and passes vacuously:

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
```

Scope it to those two paths, not to `QuestKeeperShared/` as a whole: `WidgetDungeonDerivation` and `RetentionEventRecorder` legitimately hold local `urgency`/`mobLevel`/`retry` bindings that the pattern would flag.
If `Quest` moves again, move the guard with it.

## Source Map

Feature code is grouped by role under `QuestKeeper/`; the widget and the code it shares with the app live in sibling targets.

- `Models/` — the app-side value types: `QuestSnapshot` (what derivation operates on, never the `@Model` class) and `QuestTitlePolicy`.
  The `Quest` `@Model` itself and the `Importance` enum live in `QuestKeeperShared/Quest.swift`, because the widget extension needs them too.
- `Derivation/` — the pure layer. New gamification rules belong here, never as stored state.
  - `QuestOutcome.swift`: the `QuestOutcome` enum (per-quest derived status) plus the `QuestSnapshot` methods that read it — `outcome(at:)`, `urgency(at:)` (0…1, rising as the deadline nears within `GameBalance.urgencyHorizon`, and 0 unless `.pending`), `mobLevel(at:)` (`importance` × `urgency`, mapped into `0…GameBalance.maxMobLevel`), and `isVisibleDailyGrave(at:calendar:)`.
    A grave is visible **only while its `deadline` falls on the same local calendar day as `now`** (`Calendar.isDate(_:inSameDayAs:)`) — misses outside that day are hidden by derivation, never deleted from the store.
  - `HeroDerivation.swift`: produces `HeroState` — `totalVictories`, `dailyGraves`, and `deathsWhileAway` (quests whose deadline fell in `(lastOpened, now]` and resolved to a grave, which drives the reopen replay).
    It is **a scoreboard, not a health meter: the hero is always alive.** There is no `hp` and no `isDead` anywhere in the codebase — a missed deadline is a momentary "꿱 → revive" _event_, not a lingering state.
  - `GameBalance.swift`: tunable constants — `maxMobLevel`, `urgencyHorizon` (7 days), `mourningDuration`, `notificationLeadTime` (1 hour), and `longQuestWarningHorizon` (7 days), which gates the elder-guide chunking prompt in the quest editor.
- `Actions/` — fact mutations, as opposed to derivation. `QuestActions.retryDeadlineTomorrow` ("내일 도전하기") overwrites the `deadline` fact to tomorrow; `Activation.reconstructOnActivation` runs the scenePhase `.active` replay that reconstructs deaths between `lastOpened` and `now`.
- `Views/` — the SwiftUI dungeon UI. Root is `HomeDungeonBoardView`, rows are `QuestRow`, battle transitions are `QuestBattleResolution`.
- `DailyFocus/`, `Onboarding/`, `Recovery/` — later behavior layers, each following the same pure-function shape as `Derivation/`: `DailyFocusState`, `OnboardingFlowState`, and `RecoveryState` compute a presentation value from facts plus `now`, and hold no stored state of their own.
- `Measurement/` — `RetentionBaselineWriter`, the app-side writer for the retention baseline report.
- `Notifications/` and `WidgetSupport/` — see the section below.
- `QuestKeeperShared/` — everything both targets need. Beyond the widget payload trio (`WidgetDungeonPayload`, `WidgetDungeonDerivation`, `WidgetDungeonSnapshotStore`) it holds the `Quest`/`Importance` model, `QuestModelContainer` (opens the App Group store), the `QuestStoreActor` (`@ModelActor`) the widget writes through, the pixel-art primitives (`PixelSprite`, `DungeonPalette`), and the measurement stack — retention, onboarding-experiment, and daily-focus models, recorders, and report types.
  The widget-side derivation is deliberately duplicated here so the widget can render derived state without the app running.
- `QuestKeeperWidget/` — the WidgetKit extension; a Home Screen dungeon in `systemSmall` / `systemMedium`. Mostly a read view over the snapshot, plus `CompleteQuestIntent` for one-tap completion (see below).
- `QuestKeeperTests/` — Swift Testing coverage, one `<Subject>Tests.swift` file per subject (`DerivationTests`, `QuestActionsTests`, `WidgetTimelinePolicyTests`, …); `Fixtures/` holds the shared builders. `QuestKeeperUITests/` is the XCTest target.

Bundle IDs are `kr.donminzzi.QuestKeeper` (app) and `kr.donminzzi.QuestKeeper.Widget` (widget); the App Group `group.kr.donminzzi.QuestKeeper` appears in both entitlements files and in `WidgetDungeonSnapshotStore.appGroupIdentifier`.

## Notifications and the Widget Are Side Effects

Neither is a source of truth, and neither may put its own bookkeeping on `Quest` — no notification IDs, widget IDs, or fired-at timestamps on a `@Model`.
The widget _may_ write a raw fact: `CompleteQuestIntent` commits `completedAt` through `QuestStoreActor`. That is the same fact the app writes, so the boundary is derived-state-vs-fact, not app-vs-widget.

- `QuestNotificationService` is the service class, and `QuestNotificationCenter` is a protocol whose `SystemQuestNotificationCenter` implementation wraps `UNUserNotificationCenter`.
  **That protocol is the test seam** — inject a fake instead of reaching for the real notification center in tests.
  Authorization state is the `QuestNotificationAuthorization` enum.
- `QuestNotificationPlanner` does the planning purely: given quests plus `now` it computes the desired pending requests (due-soon and deadline) as a `QuestNotificationPlan` / `QuestNotificationKind`.
  Triggers are `UNCalendarNotificationTrigger`.
- The lifecycle is **remove-before-add sync**: completion or delete cancels, retry-tomorrow reschedules, and activation reconciles pending against desired.
  Tap routing goes through `NotificationDelegate` and `NotificationRouteStore`.
- The app writes an App Group JSON snapshot through `QuestKeeper/WidgetSupport/WidgetDungeonSnapshotWriter.swift`, which maps quests to `WidgetDungeonPayload`; `WidgetDungeonSnapshotStore` persists it.
  The widget renders from that snapshot, and WidgetKit refreshes after app mutations.
- `CompleteQuestIntent` (widget process) opens the store via `QuestModelContainer.make()`, writes `completedAt` through `QuestStoreActor`, cancels that quest's notifications, rewrites the snapshot, and reloads the timeline. It is idempotent — a stale double-tap is a no-op.
  A warm-foregrounded app does **not** see that cross-process write; `QuestKeeperApp.syncActivation(using:)` swaps in a fresh `ModelContainer` on the `.active` transition to pick it up. Quest-data-dependent activation work belongs there, never in `ContentView`.
- Notification copy is informational, never shame-based.
- Suites: `QuestNotificationServiceTests`, `QuestNotificationPlannerTests`, `NotificationRoutingTests`, `WidgetDungeonPayloadTests`, `WidgetDungeonSnapshotStoreTests`, `WidgetDungeonSnapshotWriterTests`, `WidgetTimelinePolicyTests`, `WidgetNotificationCancellationTests`, `QuestStoreActorTests`.

## Build, Run, Test

Scheme `QuestKeeper`, project `QuestKeeper.xcodeproj` (no workspace, no SPM/CocoaPods yet).

**Which toolchain depends on the environment: the XcodeBuildMCP tools (`mcp__xcodebuild__*`) are exposed only in the Codex environment.**
In Claude Code and any other agent they are not available, so raw `xcodebuild` (below) is the path there — do not assume the MCP is present.

**Codex — prefer XcodeBuildMCP.** It reuses one dedicated workspace and pins the simulator by **UDID**, avoiding the raw-`xcodebuild` failure mode described below.
Session defaults are persisted in `.xcodebuildmcp/config.yaml` (git-ignored): project `QuestKeeper.xcodeproj`, scheme `QuestKeeper`, configuration `Debug`, and a pinned simulator UDID.
**Confirm the pinned UDID against your machine** with `xcrun simctl list devices available` — simulator UDIDs are recreated and drift (the previously documented `7ED9020C-A21E-425F-AF74-C71C40DA0A13` is already stale; `iPhone 17e` is currently `CDF2239B-B46C-4A44-A09E-ED656EF7F9EA`).

```text
# Once per session, confirm defaults (required before the first build/run/test):
mcp__xcodebuild__session_show_defaults

# Then, with no args (uses the pinned defaults):
mcp__xcodebuild__build_run_sim          # build + install + launch on the sim
mcp__xcodebuild__test_sim               # run the test suite
mcp__xcodebuild__test_sim  extraArgs: ["-only-testing:QuestKeeperTests"]                 # unit tests only (Swift Testing)
mcp__xcodebuild__test_sim  extraArgs: ["-only-testing:QuestKeeperTests/DerivationTests/determinism"]  # a single test
mcp__xcodebuild__screenshot             # capture the running sim
```

**Claude Code and any non-Codex agent — use raw `xcodebuild` (this is the primary path there, not a fallback).**
Always target the device by **id (UDID), never `name`**: `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 17e'` spins up a fresh ephemeral clone per run, which exhausts simulator memory and wedges the runtime (`server died` / `crashed before establishing connection`).
Name matching also breaks outright whenever a duplicate device shares the name (destination-name ambiguity) — as of 2026-08-05 only one `iPhone 17e` exists, but a UDID destination is immune either way.
Confirm/replace the UDID with `xcrun simctl list devices available` first, and prefer an already-booted simulator to respect the one-heavy-job-at-a-time limit.

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=CDF2239B-B46C-4A44-A09E-ED656EF7F9EA' \
  -only-testing:QuestKeeperTests
```

Day-to-day, building/running in Xcode is expected; use XcodeBuildMCP (Codex) or raw `xcodebuild` (elsewhere) for headless verification.

## Conventions & Constraints

- **Test framework:** unit tests (`QuestKeeperTests`) use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest.
  Only the UI tests (`QuestKeeperUITests`) use XCTest.
  Match the target you're writing in.
- **Concurrency:** `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete` are set on all targets (plus `SWIFT_APPROACHABLE_CONCURRENCY = YES`).
  Code must compile clean under **Swift 6 strict concurrency** (`Sendable`, actors, `async/await`) with no new warnings.
- **Platform:** iPhone-only per BLUEPRINT, and the wiring already reflects it — `TARGETED_DEVICE_FAMILY = 1`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `IPHONEOS_DEPLOYMENT_TARGET = 26.5`, no `#if os(macOS)` branches.
  Do not reintroduce macOS / visionOS support.
- **Dependencies:** minimize third-party deps — building on Apple 1st-party stacks by hand is the point.
  Justify any SPM package against the learning goal before adding it.
  In-scope stacks: SwiftData (`@Model`, `@Query`), UserNotifications (`UNCalendarNotificationTrigger`), WidgetKit + App Group, `TimelineView`.
- **Out of scope (Phase 1):** CloudKit/sync, accounts/login, backend, ARKit, SpriteKit particles, multi-device.
  Local-only, single-device, offline-first.
- **Naming:** derivation and action namespaces are caseless `nonisolated enum`s used as static-function namespaces (`HeroDerivation`, `GameBalance`, `QuestActions`, `QuestNotificationPlanner`, `WidgetDungeonDerivation`); state values are `nonisolated struct`s (`HeroState`, `QuestSnapshot`, `WidgetDungeonPayload`).
- **Language:** Korean comments and user-facing strings are intentional — do not translate them.
  Code identifiers and commit messages are English.
- **Voice:** quest-flavored but shame-free — `전투 추가`, `내일 도전하기`, `완료`; never `실패했습니다`, `무덤이 누적되었습니다`, `HP가 감소했습니다`.
  `DESIGN.md` (Voice) owns this.
