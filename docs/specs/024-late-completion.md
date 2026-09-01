# Recording a Late Completion

Tracked as Linear AND-159.

## Goal

Let a user record that they actually finished a quest whose deadline has already passed.
Today the detail sheet offers a missed quest only `내일 도전하기`, so someone who already did the work has to pretend they will redo it, or leave the fact unrecorded.

This adds an entry point.
It does not redefine what a missed deadline means.

## Stored Facts

No new stored fact, and no schema change.
Recording a late completion writes the same `Quest.completedAt` that an on-time completion writes.

**`completedAt` is the moment the user records it, never the deadline.**
Backdating to the deadline would falsify the record, and it would flip the derived outcome to `.victory`, contradicting the rule the derivation already carries.

## Derived Semantics — Unchanged On Purpose

`QuestSnapshot.outcome(at:)` already answers this case:

```swift
if let completedAt {
    return completedAt <= deadline ? .victory : .grave   // late completion is still a grave
}
```

So the decision is already made and documented in the code: a late completion does not convert a grave into a victory, because the hero already fell.
This spec cites that rule; it does not reopen it.

What follows from it:

- `HeroState.totalVictories` does not increase.
- The Hall of Fame does not list the quest, because `HallOfFameState.victoryQuestIDs` requires `.victory`.
- `isVisibleDailyGrave(at:)` still returns `true` while the deadline falls on the current local day, so the quest stays in the daily grave section for the rest of that day.

That last point is deliberate.
`isVisibleDailyGrave` is scoped to the deadline's local day, `WidgetDungeonDerivation` duplicates the same branch for the widget, and `WidgetMobState` carries no completion fact, so narrowing the predicate here would fork the two derivations rather than align them.

## Presentation

**The recorded completion must be visible on the board.**
Because the quest stays in the daily grave section, an unmarked row would make the action look like it did nothing.
`DailyGraveRow` gains a third style variant alongside `mourning` and `rest`, selected when `completedAt != nil`, carrying its own caption and accessibility value.
The row keeps the grave artwork: the outcome is still a grave.

**The detail sheet offers the two recovery choices only while the quest is uncompleted.**
For a visible daily grave with no `completedAt`, both `내일 도전하기` and the new record-completion action are available, including when the sheet was reached from a notification tap.
Once a completion is recorded, neither is offered again.

That second half is not optional politeness.
`QuestActions.retryTomorrow` sets `completedAt = nil`, so leaving retry available after a recorded completion would silently discard the fact the user just recorded.

**Voice.**
The action reads `완료로 기록하기` / `Record as complete`, and the row caption reads `완료로 기록함` / `Recorded as complete`.
Neither names the miss. `DESIGN.md` (Voice) owns this.

## Side Effects — By Reuse, Not By Invention

The action routes into `ContentView.complete(_:at:)`, the same path the board's completion control uses.
Everything the issue asks to be specified therefore has the same answer as an on-time completion:

- **Retention event** — `RetentionEventRecorder.recordQuestCompleted(source: .app)`.
  Lateness is not a new source: the event carries `completedAt` and the quest carries `deadline`, so a report derives it.
- **Deadline notification cleanup** — the same reconcile-or-cancel branch.
  The deadline notification has already fired by definition, so this prunes the delivered alert rather than a pending request.
- **Widget snapshot** — rewritten through the same commit-before-publish sequence.
- **Reengagement attribution** — consumed on the same terms, when the completion follows a reengagement notification for that quest.

## Non-Goals

- The widget still renders the quest inside its daily-grave **count** and offers no completion control for it. `WidgetMobState` carries no completion fact, and adding one is a payload change beyond this issue.
- Completing a grave whose deadline fell on an earlier local day. Derivation hides those from the board, so there is no surface to act from.
- Any change to victory counting, the Hall of Fame, or `GameBalance`.

## Verification

- `QuestDetailCapabilities.make` gains coverage for the uncompleted visible grave (both actions) and the late-completed grave (neither), alongside the existing pending, victory, and older-grave cases, so no branch is left inferred.
  The late-completed case asserts its two preconditions — the outcome is still `.grave` and the quest is still a visible daily grave — so `.readOnly` cannot pass for the wrong reason.
- `DailyGraveRow.Style.make(isCompleted:isNewlyMissed:)` is extracted for exactly this: the row is the only feedback the user gets, and without a seam the variant would ship unasserted.
  The tests cover the recorded variant winning over mourning, its accessibility value, and both existing variants staying put.
- The facts this change relies on are already owned elsewhere and are not re-asserted here: `DerivationTests` owns "a late completion resolves to `.grave`", and `QuestActionsTests` owns "`complete` records the action timestamp".
- `bash scripts/test-localization.sh` covers the two new catalog keys in both locales.
