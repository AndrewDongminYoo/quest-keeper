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

**The shortcut path refreshes the reengagement requests; it does not run a full reconcile.**
A full `reconcile` would plan the reminder, and it would also do two things that are wrong from a background caller.
It prunes the whole board's _delivered_ notifications, so creating an unrelated quest from a shortcut would silently clear alerts the user has not opened.
And it clears every pending request before re-adding, so one failed `add` would leave the rest of the board unscheduled until the app is next opened, where the single-quest sync's failure path restores what it evicted.

So the service gains `syncAndRefreshReengagement(snapshot:board:now:locale:)`, which syncs the created quest through the existing capacity-reserving `sync` and then rewrites only the reengagement identifiers.
It removes no delivered notification and touches no other quest's requests.
`reconcile` and `performReconcile` are unchanged; the app's activation path keeps its own semantics, which are correct for a foreground caller.

The first draft of this change did call `reconcile` from the shortcut path.
Both regressions were raised as P2 findings on PR #55 and are the reason for the narrower entry point.

**Only obsolete reminder identifiers are removed, and the sync and the refresh share one queue slot.**
Removing every pending reengagement request before adding would delete a working reminder whenever the replacing `add` then failed, which is the same defect the paragraph above rejects one level down.
`UNUserNotificationCenter` drops a pending request that shares an identifier, so the identifiers the new plan covers are replaced by the add itself and only the uncovered ones need removing.
The sync and the refresh also run inside a single `enqueue`: releasing the queue between them would let a second shortcut creation interleave, and the later refresh could then write a reminder planned from the older board.
Both were found by a local review round before the change was pushed.

**A failed board read leaves the reengagement requests alone.**
`board` is optional. Rewriting the reminder from a board that failed to load would aim it at a partial view, and removing the pending requests without replacing them is worse than leaving a slightly stale target.
The created quest's own notifications are still synced, which is exactly today's behaviour.
That failure is already visible to the caller: the same read backs the widget payload, so `didUpdateWidgetSnapshot` goes false and `followUpFailures` reports `.widgetSnapshot`.

## Touch Points

1. `QuestKeeperShared/QuestSnapshot.swift` — moved from `QuestKeeper/Models/`.
2. `QuestKeeperShared/QuestStoreActor.swift` — `snapshots()` returning the current quest snapshots.
3. `QuestKeeper/Notifications/QuestNotificationService.swift` — `syncAndRefreshReengagement` and its `performReengagementRefresh`, both added; nothing existing changes.
4. `QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift` — the `ScheduleNotifications` closure gains the optional board, and its `convenience init` calls the new entry point.
5. `QuestKeeperTests/QuestNotificationServiceTests.swift` and `QuestShortcutCreationCoordinatorTests.swift`.

`QuestKeeper/Models/` still holds `HeroAppearance.swift` after the move, and it never held a `@Model`, so the persistence guard's first path was already scanning no `@Model` and its scope is unchanged by this work.

## Verification

Written before the implementation, per the issue's own list.

1. A service test: with reminders configured, a single-quest sync leaves no reengagement request, and the shortcut entry point that follows schedules it.
   The fake notification center must be able to hold a reengagement identifier — a fake filtered to quest identifiers would pass without the fix.
2. A coordinator test: the full snapshot set, not just the created quest, reaches the notification closure.
3. A service test that another quest's pending requests and delivered alerts both survive the shortcut path, which is the regression the first draft introduced.
4. A service test that an unreadable board leaves an existing reengagement request in place rather than removing it.
5. `xcodebuild test -only-testing:QuestKeeperTests` with `-parallel-testing-enabled NO`, plus `bash scripts/test-localization.sh` if any string changes.
