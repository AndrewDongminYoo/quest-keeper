# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

QuestKeeper is a **native iOS gamified to-do app** (SwiftUI + SwiftData) whose real purpose is a learning project: crossing OS boundaries (background time judgment, local-notification lifecycle, widgets, app lifecycle, 1st-party data stack) directly in native code instead of hiding behind a Flutter/RN bridge.
The gamification (deadline miss → the pixel hero dies) is the vehicle that pulls the learning curriculum along, not the end goal.

`BLUEPRINT.md` is the authoritative roadmap — read it before any feature work.
It defines the phases, success criteria, and the non-negotiable core principle below.
This file summarizes the parts that shape *how* to write code here; BLUEPRINT owns *what* to build and in *what order*.

**Current state:** the boilerplate template is gone — `Quest` (`@Model`) replaced `Item`, and `ContentView` is now the Phase 2 dungeon root, not template scaffolding.
Phases 1–5 are largely implemented: the fact-only SwiftData model (`QuestKeeper/Models/`), the pure derivation layer (`QuestKeeper/Derivation/`), the dungeon UI with completion/retry/daily-grave/edit flows (`QuestKeeper/Views/`), the local-notification lifecycle (`QuestKeeper/Notifications/`), and the WidgetKit App Group snapshot (`QuestKeeperShared/`, `QuestKeeperWidget/`).
Extend the established per-role layer conventions; `docs/specs/` holds the per-phase contracts.

## Docs Layout

Additional docs live under `docs/` — `docs/notes/` (working notes), `docs/plans/` (implementation plans), `docs/specs/` (specifications).
The first spec is `docs/specs/001-project-setup.md` (Phase 0: platform scoping, Swift 6, boilerplate cleanup).

## Core Design Principle — "Persist facts only, derive state"

This is the architectural spine.
Every gamification rule must preserve it:

- **Persist**: only immutable raw facts — `task.deadline`, `task.completedAt`, `task.importance`.
- **Derive**: hero HP, `isDead`, mob level, urgency — all computed **against the current time at read time**, never stored.
- Deadline judgment is **state replay, not event-driven**: on app reopen, compare `lastOpened` against each task's `deadline` to retroactively reconstruct which heroes should have died in between.
- `urgency = f(time remaining until deadline)` — a derived, time-varying axis (turns the Eisenhower matrix into a live-moving one). `mobLevel = importance (stored) × urgency (derived)`.

Concrete guardrail: a `@Model` must never contain a derived-state field (`hp`, `isDead`, `mobLevel`, `urgency`).
If you're tempted to store one, it belongs in a pure derivation function instead.
The derivation entry point `HeroDerivation.state(quests:now:lastOpened:calendar:)` must stay a pure function — same inputs, same output (deterministic).

## Build, Run, Test

Scheme `QuestKeeper`, project `QuestKeeper.xcodeproj` (no workspace, no SPM/CocoaPods yet).

**Prefer the XcodeBuildMCP tools (`mcp__xcodebuild__*`) over raw `xcodebuild` for all headless build/run/test/screenshot work.**
Raw `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 17e'` spins up a fresh ephemeral test clone per run and, because a duplicate device named `iPhone 17e` exists, hits destination-name ambiguity — together these exhaust simulator memory and wedge the runtime (repeated `server died` / `crashed before establishing connection`).
XcodeBuildMCP avoids both: it reuses one dedicated workspace and pins the simulator by **UDID**.

Session defaults are already set and persisted (`.xcodebuildmcp/config.yaml`, git-ignored):
project `QuestKeeper.xcodeproj`, scheme `QuestKeeper`, configuration `Debug`, simulator UDID `7ED9020C-A21E-425F-AF74-C71C40DA0A13` (`iPhone 17e`).

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

Fallback only if the MCP is unavailable — always target the device by **id (UDID), never `name`**, to dodge the duplicate-name ambiguity:

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=7ED9020C-A21E-425F-AF74-C71C40DA0A13' \
  -only-testing:QuestKeeperTests
```

Day-to-day, building/running in Xcode is expected; use XcodeBuildMCP for headless verification.
Confirm the UDID against your machine with `xcrun simctl list devices available` if the pinned simulator is missing.

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
- **Language:** Korean comments and user-facing strings are intentional — do not translate them.
  Code identifiers and commit messages are English.
```
