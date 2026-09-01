# Implementation Plan — Recording a Late Completion

Contract: `docs/specs/024-late-completion.md`. Tracked as Linear AND-159.

## Why the diff is small

The derivation already resolves a late completion, and `ContentView.complete(_:at:)` already performs every side effect the issue asks about.
What is missing is only the entry point and the feedback that the entry point did something.
Anything that grows the derivation layer is out of scope and means the change has drifted.

## Sequence

1. **`QuestDetailCapabilities`** — add `canRecordLateCompletion`.
   Both it and the existing `canRetryTomorrow` become false once `snapshot.isCompleted`, because `QuestActions.retryTomorrow` clears `completedAt` and would discard a recorded completion.
   `.victory` and a non-visible grave stay `.readOnly`.

2. **`AppStrings` + both catalogs** — `quest.action.recordLateCompletion` and `quest.grave.recordedComplete`, Korean `defaultValue` with an English peer.
   `QuestKeeperShared` is not involved, so only the app catalog changes.

3. **`QuestDetailView`** — an `onRecordLateCompletion` closure mirroring `onRetryTomorrow`, rendered in the same section, above retry so the already-done case is read first.

4. **`ContentView`** — wire it to the existing `complete(quest)` and clear the route, exactly as the retry wiring does.

5. **`DailyGraveRow.Style`** — a third variant selected on `quest.completedAt != nil`, keeping the grave artwork and supplying its own caption and accessibility value.

## Verification order

`swiftc -typecheck` first, then the unit suite in the background — a cold cycle here is about twenty minutes because `-only-testing` still builds the UI-test runner.
Each new test is proved able to fail before it is trusted; two implementations in this repo have passed the whole suite while being wrong.
`bash scripts/test-localization.sh` runs alongside, since it is a shell script over the catalogs and contends with nothing.

## Risks

**A gate written for another feature can swallow the new capability.**
`QuestDetailCapabilities.make` switches on the outcome, so the new field has to be set on every branch rather than defaulted, or the record action silently never appears while the suite stays green.

**The row variant is the only feedback the user gets.**
The quest stays in the daily grave section by design, so if the style variant does not render, the action is indistinguishable from a no-op — and a widget test cannot see it, because the widget payload carries no completion fact for a grave.
