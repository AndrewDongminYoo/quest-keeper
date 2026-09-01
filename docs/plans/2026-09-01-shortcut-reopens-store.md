# Reopen the Store on the Shortcut Creation Path

Tracked as GitHub issue #56.
This is a defect against the widget snapshot contract in `docs/specs/009-interactive-widget-complete.md`, not a new feature, so it amends no spec and mints no new spec number.

## The Defect

`CreateQuestIntent` runs in the app process in the background, without a scene activation.
It reaches the store through the `ModelContainer` that `QuestKeeperApp` injected into `QuestShortcutCreationCoordinator`, which is whatever container the app last held.

A warm `ModelContainer` does not see writes another process committed.
That is the whole reason `QuestKeeperApp` swaps in a fresh container on the `.active` transition, and it is recorded in the `swiftdata-cross-process-warm-visibility` project note.
The shortcut path has no activation, so nothing swaps its container.

The consequence is a lost widget completion.
`CompleteQuestIntent` runs in the widget process, writes `completedAt`, and rewrites the App Group payload.
If a shortcut creation then reads the board through the warm container, that read misses the completion, and the payload it publishes carries the quest as still pending.

The writer cannot order the two:

```swift
guard payload.generatedAt >= latestSubmittedAt else { return false }
latestSubmittedAt = payload.generatedAt
```

`latestSubmittedAt` is in-memory state in one process, so it says nothing about what the widget process wrote.
The stale payload is generated later than the widget's, so it carries a newer timestamp and wins on every ordering rule available here.
The widget re-renders the completed quest as pending until the next write.

## Design Decision — Reopen Rather Than Order

**Rejected: make the writer's ordering durable.**
Issue #56 lists this as a candidate, and it does not work.
Durable ordering can only compare timestamps, and the stale payload's timestamp is genuinely the newer one — it is derived after the widget's write, from data that predates it.
Ordering by `generatedAt` cannot distinguish "written later" from "derived from later facts", and there is no other fact in the payload to order on.

**Chosen: reopen the store for the whole shortcut call.**
The coordinator gains a `ReopenStore` closure and runs `create`, `snapshots()`, and `snapshotPayload()` on one reopened container, falling back to the injected one when the reopen fails.

The reopen covers the whole call rather than only the payload read.
The board read that feeds the reengagement refresh has the identical staleness, so fixing only the payload read would leave a sibling caller broken.
Running the write and the reads on two different containers would also mean reasoning about which of them holds the created quest.

**The reopen is a closure, not an unconditional `QuestModelContainer.make()`.**
The caller owns which store a run is allowed to touch.
A fallback run, a UI-testing run, and an in-memory run each stay on their own container, and reaching the real App Group store from any of them would write facts that run was deliberately kept away from.
`QuestKeeperApp` supplies the closure under the same two conditions the `.active` container swap already answers: `ActivationPolicy.shouldUseInertSideEffects` and `ActivationPolicy.shouldReuseContainerOnBackground`.

## A Correction to a Comment That Contradicts This

`QuestKeeperApp.syncActivation`'s doc comment said that opening a second container for the same store "would trap in SwiftData".
Two measurements in this repo contradict it: issue #56's own probe held two containers over one store file live at the same time, and the `.active` branch a few lines above already calls `QuestModelContainer.make()` while `sharedModelContainer` still holds the previous container.
The comment now states the actual reason `syncActivation` lives in the app rather than in `ContentView` — the swap above has already produced the fresh container it needs.
Leaving prose that contradicts this change would invite a later reader to revert it.

## Verification

**What the suite gates.**
`QuestShortcutCreationCoordinatorTests.readsAndWritesThroughTheReopenedStore` injects two separate in-memory stores, seeds the reopened one with a quest the injected one does not have, and asserts that the created quest, the board handed to the notification refresh, and the published widget payload all come from the reopened store.
`fallsBackToTheInjectedContainer` covers the reopen returning `nil`.
Both were proved able to fail before being trusted: with the reopen removed, the first reports the missing quest in the payload and the board.

**The window narrows; it does not close.**
A `CompleteQuestIntent` commit landing after `reopenStore()` and before `snapshotPayload()` is still invisible to the reopened container, so the shortcut can still publish a stale payload.
What changes is the size of the window: from "since the app was last foregrounded", which is unbounded, to one shortcut invocation, whose dominant cost is the notification work's `UNUserNotificationCenter` round trips.

Reopening a second time before the payload read relocates that gap rather than removing it, so it is not the fix.
No cheap durable ordering closes it either: `latestSubmittedAt` is per-process, the stale payload's `generatedAt` is genuinely the newer one, and a monotonic-completion rule in the writer is unavailable because `QuestActions.uncomplete` and `QuestActions.retryTomorrow` both clear `completedAt`, which makes un-completion a legitimate transition.
Closing the class needs cross-process ordering that the App Group store itself owns.
Raised as a P2 on PR #64 and scoped out as issue #65.

**What the suite cannot gate, and why no test claims to.**
That a reopened container sees a write committed by the _widget process_ is not observable from this suite.
Issue #56 records the measurement: two containers over the same store file in one process share the coordinator's cache, and the warm one already sees the other's write, so a regression test built on that shape passes with or without this change and reads as evidence the defect does not exist.
The property this change actually turns on is cross-process, and its gate is a device or two-process spike, which this change does not build.
`QuestStoreActorTests`' own header already says the same thing about cross-process visibility.
