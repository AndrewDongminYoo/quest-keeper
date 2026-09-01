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

**The quest editor does not go through it either, and it is the app's most common write.**
`QuestEditor.save()` mutates or inserts into the shared context, calls `onSaved`, and dismisses without saving, relying on autosave.
`handleQuestSaved` now commits first and publishes nothing for a write the store did not take, matching `complete` and `delete`.
`onSaved` reports that outcome back, because the editor's follow-up notification sync reads the saved quest and a refused save rolls a newly inserted one out of the context.
The editor still dismisses either way: the board carries the banner, and a sheet left open with an inert Save button reads as unresponsive rather than as feedback.
When the editor was opened from the detail sheet, its own dismissal only uncovers that sheet, so a refused edit closes the detail route too — otherwise the banner stays hidden until the user happens to back out.

**Two more user-triggered writes do not go through it, and need routing in by hand.**
`RoutineCompletionRecorder.record` and `DailyFocusSelectionRecorder.record` own their own `save()` and report `inserted` / `unchanged` / `failed`, so a routine completion or a daily-focus selection would otherwise fail silently — and, worse, succeed without ever clearing a standing banner.
Both report their result through the same rule.

**A refused write and a rejected action are not the same thing, and the banner must not conflate them.**
`RoutineCompletionRecorder` returns `failed` both when the store throws and when the completion simply does not apply — the rule is gone, or the routine rotated out of today's roster past local midnight.
Only the first is a refused write. It gains a `rejected` case so the second reports as nothing written; otherwise a stale tap would tell the user to retry something that cannot succeed.
`DailyFocusSelectionRecorder` had the same conflation and is split the same way: five validation guards return `rejected`, and only the trailing `catch` — which covers both the save and the reads it depends on — stays `failed`.
The sheet staying open is an accurate surface for a rejection but does not distinguish one from a storage failure, which is why the split was needed rather than deferred.

**A write that never happened is not a write that succeeded.**
`commitPendingChanges` returns `true` without saving when there are no pending changes, and both recorders return `unchanged` for an idempotent repeat.
Treating either as a success would let a no-op erase a warning about a write that really was refused, so the rule has three cases rather than a `Bool`, and it lives in `QuestWriteFeedback` — outside the `View`, where a unit test can reach it.

## The Surface

**One informational banner pinned below the board's scrolling content**, built like `StoreFailureBanner`: a composed label, not a `Button`, because there is no action to take from it beyond retrying the thing you just did.

The banner is the surface for every path, including the two presented in `QuestDetailView`.
An inline message in the sheet was rejected: the sheet calls `dismiss()` itself immediately after invoking its action closure, so it is already closing, and a sheet that declines to close reads as an unresponsive button rather than as feedback.
Every one of the nine paths ends with the board on screen, so the board is the one place that can answer all of them.

**It is pinned rather than placed in the scrolled content**, unlike `StoreFailureBanner`, which renders at launch when there is nowhere to scroll yet.
This one appears in response to an action the user can take anywhere on the board, so inside the `LazyVStack` it would land above the viewport and the rejected write would look like it worked.

**It clears on the next successful commit**, which is the only event that shows the store is taking writes again.
Like `storeFailedToOpen`, it is a standing condition rather than a toast: a store that rejects writes does not stop being a problem after a few seconds.

**Voice.**
`방금 변경을 저장하지 못했습니다` / `That change wasn't saved`, with the body naming what the user is looking at: the board still shows what is on disk.
The failure is the app's, and the copy says so without blaming the user. `DESIGN.md` (Voice) owns this, and its avoid-list binds English too.

## Non-Goals

- Retrying the write automatically. A rejected save means the store is refusing, and a silent retry loop would hide that.
- Keeping the detail sheet open, per the reasoning above.
- **Writes made from a sheet that stays presented afterwards.** The routine editor, the routine management sheet, and the daily-focus selection sheet all raise the banner onto a board they are covering. Closing them one at a time is the losing move — three review rounds each found one more instance at a new call site — so where a refused write should be told when the user is inside a sheet is its own design question. Tracked as issue #71.
- Distinguishing _which_ mutation was rejected. The banner reports that the last write did not land; the board already shows the actual state, which is the more reliable answer.

## Verification

`QuestKeeperTests` cannot reach this: `commitPendingChanges` is private to a SwiftUI `View`, and no unit test in this suite can make `ModelContext.save()` throw.

The gate is therefore a UI test built on the pattern `StoreFailureUITests` already established for the sibling condition.
A DEBUG launch argument throws **inside the same `do` block the real save failure lands in**, so the run exercises the actual catch → rollback → banner path rather than setting the flag and asserting a view that never had to derive it.

The test taps a completion on a seeded board and asserts three things, because any one alone would pass for the wrong reason:

- the banner exists,
- its label carries the words, not merely the identifier — an identifier-only assertion is what let four English defects ship,
- the quest is still on the board uncompleted, which is what makes the banner's claim true.

**The banner's placement is not asserted.**
The seeded board is short enough to fit on screen, so the test passes under both the pinned and the in-scroll placement and cannot see the defect that motivated the change.
Nothing in this repo checks any banner's position or its rendering at large Dynamic Type sizes.
