# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

QuestKeeper is a **native iOS gamified to-do app** (SwiftUI + SwiftData) whose real purpose is a learning project: crossing OS boundaries (background time judgment, local-notification lifecycle, widgets, app lifecycle, 1st-party data stack) directly in native code instead of hiding behind a Flutter/RN bridge.
The gamification (deadline miss → the pixel hero dies) is the vehicle that pulls the learning curriculum along, not the end goal.

`BLUEPRINT.md` is the authoritative roadmap — read it before any feature work.
It defines the phases, success criteria, and the non-negotiable core principle below.
This file summarizes the parts that shape *how* to write code here; BLUEPRINT owns *what* to build and in *what order*.

**Current state:** the repo is still the stock Xcode SwiftUI+SwiftData template (`Item.swift`, boilerplate `ContentView`).
Phase 1 has not started.
Treat `Item` and the template `ContentView` as scaffolding to be replaced, not as established patterns to extend.

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
Phase 1's `heroState(tasks:now:lastOpened:)` must be a pure function — same inputs, same output (deterministic).

## Build, Run, Test

Scheme `QuestKeeper`, project `QuestKeeper.xcodeproj` (no workspace, no SPM/CocoaPods yet).

```bash
# Build for simulator
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single unit test (Swift Testing)
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:QuestKeeperTests/QuestKeeperTests/example
```

Adjust the simulator `name` to an installed device (`xcrun simctl list devices available`).
Day-to-day, building/running in Xcode is expected; use `xcodebuild` for headless verification.

## Conventions & Constraints

- **Test framework:** unit tests (`QuestKeeperTests`) use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest.
  Only the UI tests (`QuestKeeperUITests`) use XCTest.
  Match the target you're writing in.
- **Concurrency:** `SWIFT_APPROACHABLE_CONCURRENCY = YES` is already set.
  The goal is to compile clean under **Swift 6 strict concurrency** (`Sendable`, actors, `async/await`).
  Note `SWIFT_VERSION` in the pbxproj is still `5.0` from the template — see `docs/specs/001-project-setup.md` before flipping it to 6, since it changes the whole compile contract.
- **Platform:** scope is **iOS-only** per BLUEPRINT, but the template still ships macOS / visionOS support (`SUPPORTED_PLATFORMS`, `TARGETED_DEVICE_FAMILY = "1,2,7"`, `#if os(macOS)` branches).
  Treat those branches as template noise to be removed, not a multiplatform requirement (tracked in the setup spec).
- **Dependencies:** minimize third-party deps — building on Apple 1st-party stacks by hand is the point.
  Justify any SPM package against the learning goal before adding it.
  In-scope stacks: SwiftData (`@Model`, `@Query`), UserNotifications (`UNCalendarNotificationTrigger`), WidgetKit + App Group, `TimelineView`.
- **Out of scope (Phase 1):** CloudKit/sync, accounts/login, backend, ARKit, SpriteKit particles, multi-device.
  Local-only, single-device, offline-first.
- **Language:** Korean comments and user-facing strings are intentional — do not translate them.
  Code identifiers and commit messages are English.
```
