# Bound an Unresolved Reengagement Route to Its Foreground Execution

Tracked as GitHub issue #52.
A defect against the attribution boundary in `docs/specs/023-user-controlled-reengagement-reminders.md`; it amends no spec and mints no new spec number.

## The Defect

`NotificationRouteStore.pause()` clears a _resolved_ reengagement attribution, so a completion can no longer be attributed across a background transition once the route has resolved.

An **unresolved** route is still left queued.
If a reengagement notification routes to a quest that is not yet visible in the store, and the app backgrounds before `takeRoutedQuest` resolves it, the route survives into the next foreground and can then record `reengagement_notification_opened` plus an attributed completion.
Spec 023 bounds that attribution to one foreground execution, so the completion rate can be inflated.

## Why the Obvious Fix Was Reverted

Discarding the pending route inside `pause()` was tried on PR #50 and reverted.
`pause()` runs from `onChange(of: scenePhase, initial: true)` on `.background`, and the delivery order between `UNUserNotificationCenterDelegate.didReceive` and the scene-phase transition is not guaranteed.
On a notification cold start the `.background` branch can fire _after_ the route is set and swallow a valid tap, so the notification opens nothing.
A user's tap doing nothing is worse than a rare metric inflation.

## Design

Two moves, and the split between them is what makes both requirements hold at once.

**Bound the attribution, never the navigation.**
The inflation concern is about the recorded attribution, not about which screen opens.
`pendingQuestID` should therefore survive every transition exactly as it does today — a tap always opens its quest — while the reengagement action ID is what a stale route loses.
This is what the reverted fix got wrong: it discarded both.
This half is settled and is not what blocks the change.

**Decide which foreground execution a route belongs to.**
This half is not settled, and the section below records an attempt that fails so the next one does not repeat it.

## Attempted and Rejected: Stamping From Container Readiness

`readyGeneration` increments on every `resume`, so the obvious stamp is "the generation this route arrived in", with a route that arrives before the first `resume` belonging to `readyGeneration + 1` because a cold-start tap precedes it.
`takeRoutedQuest` then drops an action ID whose stamp is older than the current generation.

It was implemented and it passes: the two new tests plus the existing `pauseClearsResolvedAttributionOnly` and `reengagementRoutesRetainOneAttributionOnlyAfterTheQuestResolves` all go green, and both new tests were proved able to fail — removing the comparison fails the stale case, and stamping unconditionally with the current generation fails the cold-start case and two pre-existing tests with it.

It is still wrong, and a local review round found why: **it reads container readiness as a proxy for foreground state, and the two are not the same signal.**
`ContentView` calls `resume(for:)` from `.onChange(of: ObjectIdentifier(modelContext.container), initial: true)`, so on a cold start that observer can run before `didReceive` and leave the store "resumed" while the scene phase has not been `.active` yet.
The tap is then stamped with the current generation, the initial `.background` callback pauses, and the first real activation increments past it — discarding a valid cold-start attribution, which is the exact regression the reverted fix was reverted for.

The code was not kept. A green suite here means the tests do not cover that ordering, not that the ordering does not happen.

## Implemented: An Explicit Foreground Signal

The store stops inferring the foreground execution; the scene phase says so.

`NotificationRouteStore.beginForeground()` is called from the `.active` branch and only from there, separate from `resume(for:)`, which both `ContentView` and the scene phase call for container readiness.
`pause()` then expires a pending action ID only when a foreground execution had actually begun, and `takeRoutedQuest` drops an expired one while always returning the quest.

The initial `.background` from `onChange(initial: true)` cannot expire anything, because no `.active` has run, and that holds regardless of how `didReceive` interleaves with either callback.
**This is the property the rejected attempt lacked: nothing here reads one signal as a proxy for another.**

The predicted cost was a call in each `.active` path in `QuestKeeperApp`, the lifecycle code the reverted fix already destabilised once. In practice one line at the top of `case .active:` covers all three paths, since the fallback branch's early return passes through it.

## Verification a Fix Needs

1. A route recorded before the first `resume` keeps its attribution after that `resume`.
2. A route recorded while resumed, left unresolved across `pause` then `resume`, resolves its quest and yields no attribution.
3. **A route recorded after `ContentView`'s container observer has resumed the store but before the first `.active` keeps its attribution.**
   This is the ordering the rejected attempt fails, and no existing test covered it — `tapBeforeFirstActivationKeepsItsAttribution` does now.
4. The existing `pauseClearsResolvedAttributionOnly` and `reengagementRoutesRetainOneAttributionOnlyAfterTheQuestResolves` stay green.
5. Each new test proved able to fail before being trusted.
6. `xcodebuild test -only-testing:QuestKeeperTests` with `-parallel-testing-enabled NO`.
