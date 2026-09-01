# A Failure Surface for a Rejected Fact Mutation

Tracked as GitHub issue #67, raised by CodeRabbit on PR #66 and scoped out there.

## Goal

When the store refuses a write, tell the user.

Today `ContentView.commitPendingChanges()` rolls the change back and returns `false`, and every caller returns having done nothing.
Nothing on screen says so.
The user who just recorded a late completion, retried a quest, or completed a routine has no way to tell the action apart from one that worked.

## Where The Fix Goes

**In `commitPendingChanges()`, not in its callers.**

Nine call sites reach it, across quest completion, retry, deletion, routine completion, routine editing, reengagement settings, and notification-route consumption.
Guarding each one would be a larger diff that still misses whichever path is added next; the single function every write already converges on is the place a rejection becomes knowable.

It records the outcome and the callers keep their present shape.

```swift
do {
    try modelContext.save()
    lastCommitFailed = false
    return true
} catch {
    modelContext.rollback()
    lastCommitFailed = true
    return false
}
```

**Two user-triggered writes do not go through it, and need routing in by hand.**
`RoutineCompletionRecorder.record` and `DailyFocusSelectionRecorder.record` own their own `save()` and report `inserted` / `unchanged` / `failed`, so a routine completion or a daily-focus selection would otherwise fail silently — and, worse, succeed without ever clearing a standing banner.
Both report their result through the same rule.

**A write that never happened is not a write that succeeded.**
`commitPendingChanges` returns `true` without saving when there are no pending changes, and both recorders return `unchanged` for an idempotent repeat.
Treating either as a success would let a no-op erase a warning about a write that really was refused, so the rule has three cases rather than a `Bool`, and it lives in `QuestWriteFeedback` — outside the `View`, where a unit test can reach it.

## The Surface

**One informational banner on the board**, alongside `StoreFailureBanner` and built the same way: a composed label, not a `Button`, because there is no action to take from it beyond retrying the thing you just did.

The banner is the surface for every path, including the two presented in `QuestDetailView`.
An inline message in the sheet was rejected: the sheet calls `dismiss()` itself immediately after invoking its action closure, so it is already closing, and a sheet that declines to close reads as an unresponsive button rather than as feedback.
Every one of the nine paths ends with the board on screen, so the board is the one place that can answer all of them.

**It clears on the next successful commit**, which is the only event that shows the store is taking writes again.
Like `storeFailedToOpen`, it is a standing condition rather than a toast: a store that rejects writes does not stop being a problem after a few seconds.

**Voice.**
`방금 변경을 저장하지 못했습니다` / `That change wasn't saved`, with the body naming what the user is looking at: the board still shows what is on disk.
The failure is the app's, and the copy says so without blaming the user. `DESIGN.md` (Voice) owns this, and its avoid-list binds English too.

## Non-Goals

- Retrying the write automatically. A rejected save means the store is refusing, and a silent retry loop would hide that.
- Keeping the detail sheet open, per the reasoning above.
- Distinguishing _which_ mutation was rejected. The banner reports that the last write did not land; the board already shows the actual state, which is the more reliable answer.

## Verification

`QuestKeeperTests` cannot reach this: `commitPendingChanges` is private to a SwiftUI `View`, and no unit test in this suite can make `ModelContext.save()` throw.

The gate is therefore a UI test built on the pattern `StoreFailureUITests` already established for the sibling condition.
A DEBUG launch argument throws **inside the same `do` block the real save failure lands in**, so the run exercises the actual catch → rollback → banner path rather than setting the flag and asserting a view that never had to derive it.

The test taps a completion on a seeded board and asserts three things, because any one alone would pass for the wrong reason:

- the banner exists,
- its label carries the words, not merely the identifier — an identifier-only assertion is what let four English defects ship,
- the quest is still on the board uncompleted, which is what makes the banner's claim true.
