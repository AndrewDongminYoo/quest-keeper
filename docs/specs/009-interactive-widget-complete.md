# Spec 009 — Interactive Widget (Complete Action)

Status: planned
Depends on: 005 (home widget), 008 (row battle transition)
Blocks: interactive retry-tomorrow; App Shortcuts / Siri

## Goal

Let the user complete a pending quest with one tap on the Home Screen widget, without opening the app, and have the completion fully committed immediately: the raw fact is written to the shared store, the pending deadline notification is cancelled, and the widget refreshes.
The app must reflect the same completion whether it cold-launches or resumes warm.

## Problem

The widget renders an App Group JSON snapshot read-only (`README.md` lists interactive widget actions as out of scope for the MVP).
Every completion currently requires opening the app.
Making the widget write-capable is the natural next native-iOS boundary: App Intents plus a cross-process SwiftData write through the App Group.

## Product Decision

Support **complete only** in this first cut, with **immediate full commit**.
Tapping `완료` on a mob writes `completedAt = now` to the shared SwiftData store, cancels that quest's pending notifications, rewrites the App Group snapshot, and reloads the widget timeline — all in the widget extension process.
Retry-tomorrow, create/edit, Lock Screen / Control widgets, and Siri are out of scope here.

## The load-bearing risk: cross-process change visibility

A separate process (the widget) committing to the SwiftData store is **not** automatically visible to the app's already-running context.
Cold relaunch reads fresh from disk and is fine; the dangerous case is a **warm foreground** — the app still in memory with a cached context and a stale `@Query`, so a widget-completed quest can render as still-pending until relaunch.
`reconstructOnActivation` also reads `quests.map(\.snapshot)` from that same `@Query`, so even the activation replay would run on stale data.

This is the un-precedented part of the feature and the design's top risk, so it is derisked **first**, before any widget wiring (see Scope §spike).
The guarantees the design commits to:

- the shared container enables persistent history tracking so cross-process writes are recoverable;
- on scenePhase `.active` the app **forces a refresh** of its store state (exact mechanism confirmed by the spike — remote-change observation, a fresh fetch, or an explicit context refresh) rather than trusting the cached context, and does this **before** `reconstructOnActivation` runs.

## Scope

In scope:

- **spike first:** derisk cross-process visibility before wiring the widget — with the app backgrounded, write `completedAt` to a quest in the shared store externally, foreground the app, and observe whether the `@Query`-driven list reflects it; the spike decides the exact refresh mechanism the app needs;
- move the `@Model Quest` (and `Importance`, plus `QuestSnapshot` if required to compile) into `QuestKeeperShared` so the widget extension links the same model type;
- add `QuestModelContainer.make()` in `QuestKeeperShared` that opens the store via an explicit App Group `groupContainer` with persistent history tracking, used by both app and widget;
- force a store refresh on scenePhase `.active` (mechanism per the spike) so a warm foreground reflects widget writes before `reconstructOnActivation` runs;
- add a `CompleteQuestIntent` (`AppIntent`) in the widget target that mutates the raw completion fact via an `@ModelActor`;
- move `QuestNotificationKind` (already a pure, `Sendable` `questID -> identifier` type) into `QuestKeeperShared` so the widget cancels the exact requests the app scheduled — no re-derivation, parity guaranteed by shared code;
- move `WidgetDungeonPayload.make(from:)` into `QuestKeeperShared` so the intent can re-derive the snapshot from the store;
- add `Button(intent:)` complete affordances to `systemMedium` (per-row) and `systemSmall` (top mob).

Out of scope:

- retry-tomorrow, create, or edit from the widget;
- Lock Screen, Control Center, or Live Activity surfaces;
- App Shortcuts / Siri exposure;
- reading the store directly from the `TimelineProvider` (retiring the JSON snapshot is a later cut);
- changing mob-level, importance, or urgency formulas;
- storing any derived state.

## UX Requirements

### Completion Flow

1. The widget shows pending mobs (existing derivation); completed quests and daily graves carry no complete button.
2. Tapping `완료` on a mob invokes `CompleteQuestIntent` for that quest id.
3. The completion is committed in the extension: `completedAt = now`, notifications cancelled, snapshot rewritten, timeline reloaded.
4. The refreshed widget reflects the victory (the mob leaves the pending list); the app shows the same state on next foreground — warm or cold — because it refreshes on `.active`.

### Families

- `systemMedium`: a compact `완료` / checkmark button on each pending mob row.
- `systemSmall`: the single most-urgent pending mob with a `완료` button.
- Korean user-facing strings stay intentional (`완료`).

### Idempotence

A tap on an already-completed quest (double tap, stale widget render) is a no-op — the fact is not overwritten and no duplicate side effects run.

## Architecture

```plaintext
[widget: tap 완료] -> CompleteQuestIntent(questID:).perform()   // widget extension process
  -> @ModelActor over QuestModelContainer.make()                // explicit App Group groupContainer + history tracking
  -> fetch Quest(id); if already completed -> no-op
  -> completedAt = now; save                                    // raw fact only
  -> UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:
       QuestNotificationKind.allCases.map { $0.identifier(for: id) })
  -> WidgetDungeonPayload.make(from: <all quests>) -> WidgetDungeonSnapshotStore.save   // guard: never drop this write
  -> WidgetKit reloads timeline

[app: scenePhase .active] -> force store refresh (per spike) -> reconstructOnActivation -> render fresh @Query
```

Shared module (`QuestKeeperShared`) owns: `Quest` / `Importance` (`@Model`), `QuestModelContainer.make()`, `QuestNotificationKind`, and `WidgetDungeonPayload.make(from:)`.
The app switches its container to `QuestModelContainer.make()` and gains the `.active` refresh.
`CompleteQuestIntent` lives in the widget target (may move to shared later for Siri).
The intent uses an `@ModelActor` for its store work — a bare `ModelContext` in an async `perform()` fights Swift 6 strict concurrency.

## Data And State Rules

- The intent writes only the raw `completedAt` fact; it never stores `hp`, `isDead`, `mobLevel`, `urgency`, victory counts, or any derived value.
- The snapshot is a projection re-derived from the store; it is not a source of truth. The snapshot rewrite must never be dropped, or the reloaded widget (which reads the JSON, not the store) shows stale.
- App and widget open the same App Group store via `QuestModelContainer.make()`; each write uses a short-lived context / `@ModelActor`.
- Notification identifiers come from the one shared `QuestNotificationKind` so app and widget always agree.
- **Store URL:** the store already resolves into the App Group container under the current default config; making `groupContainer` explicit is expected to resolve to the same path, so no data reset is anticipated. This must be **verified** (confirm the URL, and resolve why the default already lands there) before changing the persistence config — do not assume a reset either way.

## Testing Requirements

The real acceptance gate is cross-process visibility, not single-process write logic.

Automated tests must cover:

- `QuestNotificationKind.identifier(for:)` parity — the widget's cancellation identifiers equal what the app's planner schedules;
- `WidgetDungeonPayload.make(from:)` reflects a completed quest (existing payload tests extended);
- a testable completion core (`completeQuest(id:in:now:)`) against an in-memory `ModelContainer`: sets `completedAt`, is idempotent on an already-completed quest, and is a no-op for a missing id;
- existing notification and snapshot suites keep passing.

Cross-process gate (the point of the feature — cannot be proven by an in-memory single-process test):

- the **spike** result: app backgrounded → external store write → foreground → app's fetch/`@Query` reflects it;
- manual: add the widget, background the app, tap `완료` on the widget, foreground the app, and confirm the quest shows completed **warm** (not only after relaunch).

Final verification commands:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/
```

Manual verification:

- add the widget, create a near-deadline quest, tap `완료` on the widget;
- confirm the mob leaves the widget without opening the app;
- confirm the app shows the quest completed (victory count up) on next foreground, warm and cold;
- confirm the quest's pending deadline notification no longer fires;
- confirm a second tap on an already-completed mob does nothing.

## Risks

- **Cross-process change visibility (top risk):** the app's warm cached context may not see the widget's write. Mitigated by history tracking on the shared container plus a forced refresh on `.active`, and derisked by the spike before any widget wiring. Correctness routed to an adversarial `advisor` review and captured as a knowledge-wiki page (new precedent — none existed).
- **Store URL / config switch:** verify the explicit `groupContainer` resolves to the current store path before switching; treat a reset as possible but not assumed.
- **Target-membership move:** moving the `@Model` and `QuestNotificationKind` across targets is structural; the build gate for both schemes guards against breakage.

## Acceptance Criteria

- Tapping `완료` on the widget completes a pending quest with no app launch.
- The app reflects the completion on the next foreground **warm or cold**, with no manual reconciliation.
- The completion writes only `completedAt`; `Quest` remains raw facts only.
- The quest's pending notifications are cancelled by the same identifiers the app uses.
- The widget refreshes to reflect the victory.
- A repeat tap on a completed quest is a no-op.
- No third-party dependency is added.
- `QuestKeeperTests` pass and both `QuestKeeper` and `QuestKeeperWidget` schemes build on the `iPhone 17e` simulator.
