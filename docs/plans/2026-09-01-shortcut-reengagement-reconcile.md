# Reconcile Reengagement Reminders on the Shortcut Creation Path

Tracked as GitHub issue #53.
This is a defect against the contract in `docs/specs/023-user-controlled-reengagement-reminders.md`, not a new feature, so it amends no spec and mints no new spec number.

## The Defect

`QuestNotificationService.performSync` subtracts `reengagementSettingsStore.load().scheduledRequestCount` from the notification cap but never plans the reengagement requests.
Only `performReconcile` plans them.
`QuestShortcutCreationCoordinator` calls `syncWithoutRequestingAuthorization` for a quest created through `CreateQuestIntent`, and that path runs without an app activation, so nothing reconciles afterwards.

A quest created through the shortcut therefore gets its deadline notifications and nothing else.
When reminders are enabled but no reengagement request is currently scheduled — the board went empty and a reconcile removed them — the configured reminder stays absent until the app is next opened.
Where a request does exist, its target quest stays stale for the same reason.

## Design Decision — Where the Snapshots Come From

`reconcile` takes `[Quest]`, and the coordinator reaches the store through `QuestStoreActor`, so it cannot hand over `@Model` instances.
Two ways to give the service the current board were considered.

**Rejected: map the widget payload.**
`QuestStoreActor.snapshotPayload` already returns every quest, and the coordinator already calls it.
But `WidgetQuestPayload.importanceRawValue` is an `Int`, so building a `QuestSnapshot` from it needs a failable `Importance(rawValue:)` unwrap on the notification path.
A lossy round-trip through a payload type owned by a different side effect is a defect surface, not a shortcut.

**Chosen: move `QuestSnapshot` into `QuestKeeperShared` and add a store query.**
`QuestSnapshot` is a pure value projection of `Quest`'s raw facts, and `Quest` already lives in `QuestKeeperShared`.
`rg -c 'QuestSnapshot' QuestKeeperShared/ QuestKeeperWidget/` returns no matches, so the move introduces no redeclaration in the widget target.
The `Quest.snapshot` extension moves with it; the derivation extensions in `QuestKeeper/Derivation/` stay in the app target and keep working over the shared type.

## Behavior Decisions

**The shortcut path adopts `reconcile`'s denied-state wipe, deliberately.**
`performReconcile` removes every pending QuestKeeper identifier before it reads the authorization status, and returns without re-adding when the status is not `.allowed`.
Today's single-quest sync only touches the one quest's identifiers, so this is a behavior change for the shortcut path.
It is the correct one: iOS delivers nothing while authorization is denied, so the removed requests were already inert, and the next app activation rebuilds them through the same reconcile.
Making the shortcut path behave like activation is the point of the fix.

**A failed snapshot read falls back to today's single-quest sync.**
`reconcile(snapshots:)` with a partial set would remove the whole board's pending requests and re-add only the new quest, which is worse than not reconciling.
So the coordinator keeps its existing single-snapshot closure and calls it when the board read throws.
That failure is already visible to the caller: the same read backs the widget payload, so `didUpdateWidgetSnapshot` goes false and `followUpFailures` reports `.widgetSnapshot`.

## Touch Points

1. `QuestKeeperShared/QuestSnapshot.swift` — moved from `QuestKeeper/Models/`.
2. `QuestKeeperShared/QuestStoreActor.swift` — `snapshots()` returning the current quest snapshots.
3. `QuestKeeper/Notifications/QuestNotificationService.swift` — a snapshot-based `reconcile` entry point; the existing `reconcile(quests:)` delegates to it.
4. `QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift` — a `ReconcileNotifications` closure taking the full set, plus its `convenience init` and the `QuestKeeperApp` call site.
5. `QuestKeeperTests/QuestNotificationServiceTests.swift` and `QuestShortcutCreationCoordinatorTests.swift`.

`QuestKeeper/Models/` still holds `HeroAppearance.swift` after the move, and it never held a `@Model`, so the persistence guard's first path was already scanning no `@Model` and its scope is unchanged by this work.

## Verification

Written before the implementation, per the issue's own list.

1. A service test: with reminders configured, a single-quest sync followed by a board reconcile leaves the configured reengagement request scheduled.
   The fake notification center must be able to hold a reengagement identifier — a fake filtered to quest identifiers would pass without the fix.
2. A coordinator test: the full snapshot set, not just the created quest, reaches the reconcile closure.
3. `xcodebuild test -only-testing:QuestKeeperTests` with `-parallel-testing-enabled NO`, plus `bash scripts/test-localization.sh` if any string changes.
