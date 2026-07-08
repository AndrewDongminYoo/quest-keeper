# Spec 001 — Project Setup & Boilerplate Cleanup (Phase 0)

Status: proposed
Depends on: none
Blocks: Phase 1 (data model & derivation layer)

## Goal

Bring the stock Xcode template to the baseline the BLUEPRINT assumes, before any Phase 1 code lands: iOS-only platform scope, Swift 6 strict concurrency, and template boilerplate removed.
This is pure scaffolding work — no gamification logic, no data model beyond deleting the placeholder.

## Rationale

The repo is the unmodified Xcode SwiftUI+SwiftData template.
It carries multiplatform defaults (macOS, visionOS), a Swift 5 language mode, and placeholder `Item` / `ContentView` code.
BLUEPRINT fixes the scope as iOS-only, offline-first, single-device, and requires a clean Swift 6 strict-concurrency compile as a success criterion.
Leaving the template defaults in place means every later phase pays for `#if os(macOS)` branches and a language-mode flip mid-stream.
Do it once, up front.

## Scope

### 1. Platform scoping — iOS only

`QuestKeeper.xcodeproj/project.pbxproj` currently sets, across all six build-config blocks (Debug/Release × app/tests/uitests):

- `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator"`
- `TARGETED_DEVICE_FAMILY = "1,2,7"` (iPhone, iPad, visionOS)
- `XROS_DEPLOYMENT_TARGET = 26.5`, `MACOSX_DEPLOYMENT_TARGET = 26.5`

Changes:

- Set `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` in every build-config block.
- Set `TARGETED_DEVICE_FAMILY = "1"` (iPhone only) — the pixel hero + home-screen widget target the phone.
  Revisit if iPad is wanted later; not now.
- Remove the `XROS_DEPLOYMENT_TARGET` and `MACOSX_DEPLOYMENT_TARGET` lines (dead once the platforms are gone).
- Prefer editing these in Xcode's build settings UI over hand-editing `project.pbxproj`, so the pbxproj stays internally consistent.

In `QuestKeeper/ContentView.swift`, delete the multiplatform conditionals — the file should read as plain iOS SwiftUI:

- Remove the `#if os(macOS)` / `#else` split and the `NavigationViewWrapper` wrapper struct; use `NavigationStack` directly.
- Remove `.navigationSplitViewColumnWidth(...)` (macOS-only) and the `#if os(iOS)` guards around the toolbar `EditButton`.

### 2. Swift 6 strict concurrency

Currently `SWIFT_VERSION = 5.0` with `SWIFT_APPROACHABLE_CONCURRENCY = YES` already set.

Changes:

- Set `SWIFT_VERSION = 6.0` across all build-config blocks.
- Add `SWIFT_STRICT_CONCURRENCY = complete`.
- Build and drive warnings/errors to zero.
  With only template code present the surface is tiny; do this now while it is cheap, so Phase 1 is written under the final compile contract rather than migrated into it.
- Keep `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` as-is (template defaults, compatible with the goal).

### 3. Boilerplate cleanup

- `QuestKeeper/Item.swift`: leave in place for now — deleting it requires a replacement model to keep the `Schema`/`ModelContainer` compiling.
  Its removal belongs to Phase 1 when the real `Task` `@Model` is introduced.
  Do **not** extend `Item`; it is a placeholder.
- `QuestKeeper/ContentView.swift`: keep as a minimal compiling placeholder after the platform-conditional removal above.
  Real task-list UI is Phase 2.
- Do not delete the `QuestKeeperTests` / `QuestKeeperUITests` targets.
  Replace the template `example` test body when Phase 1 adds real tests.

### 4. Fixed identifiers (reference, no change needed)

- Bundle IDs: `kr.donminzzi.QuestKeeper`, `.QuestKeeperTests`, `.QuestKeeperUITests`.
- `DEVELOPMENT_TEAM = 393JTTV68D`.
- Deployment target: `IPHONEOS_DEPLOYMENT_TARGET = 26.5` (leave as set).

## Out of Scope

- App Group + WidgetKit entitlements — deferred to Phase 4 (its own spec) when the widget extension is created.
- Any `Task` model, derivation layer, or gamification logic — Phase 1.
- Notification entitlements/capabilities — Phase 3.
- Renaming `Item` → `Task` — Phase 1 (a `Task` model type also collides with Swift Concurrency's `Task`; the Phase 1 spec must decide the model's final name, e.g. `Quest`).

## Verification

1. Platform scoping → `xcodebuild -showBuildSettings -scheme QuestKeeper | grep -E 'SUPPORTED_PLATFORMS|TARGETED_DEVICE_FAMILY'` shows iOS-only, family `1`.
2. iOS-only source → `grep -rn 'os(macOS)' QuestKeeper/` returns nothing.
3. Swift 6 clean build → `xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 16'` succeeds with zero warnings under `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`.
4. Tests still wired → `xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 16'` runs the (template) test and passes.

## Open Questions

- `TARGETED_DEVICE_FAMILY`: iPhone-only (`1`) vs iPhone+iPad (`1,2`)?
  Assumed `1` per single-device / phone-widget focus — confirm before applying.
- Final model type name to avoid the `Task` / Swift Concurrency `Task` clash — decided in the Phase 1 spec, flagged here so setup doesn't reintroduce an `Item`-shaped placeholder under the wrong name.
