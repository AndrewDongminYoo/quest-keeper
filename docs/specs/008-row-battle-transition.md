# Spec 008 — Row Battle Transition

Status: planned
Depends on: 007 (home dungeon board)
Blocks: richer combat feedback pass

## Goal

Make pending quest completion feel like a short row-level battle instead of an immediate list mutation, while preserving the raw-facts model and the existing notification/widget completion lifecycle.

## Problem

The home board now makes quests easier to scan, but completion still behaves like a normal todo row.
Swiping complete immediately removes the row, so the user does not see the "one-hit victory" concept described in `BLUEPRINT.md`.
Adding a full combat engine would be scope creep, but a short row-local transition can make completion feel intentional without changing quest rules.

## Product Decision

Use a **row-delayed battle transition**.
When the user activates the complete action, the row stays visible briefly, disables further row interaction, plays a simple hit and defeated presentation, then commits completion through the existing `ContentView.complete` lifecycle.
The completion fact must use the swipe start timestamp, not the delayed commit timestamp, so a quest completed just before its deadline is not accidentally recorded as late because of animation time.

## Scope

In scope:

- add a pure battle transition policy for phase thresholds and commit delay;
- keep the pending quest row visible during completion feedback;
- disable tap, delete, and repeated complete interactions while the row is resolving;
- show a short hit/defeated presentation inside `QuestRow`;
- pass the captured completion timestamp through the existing complete callback path;
- keep notification cancellation and widget snapshot writes behind the existing `ContentView.complete` path;
- test pure transition timing and the captured timestamp contract;
- keep Korean user-facing strings intentional.

Out of scope:

- SpriteKit, SceneKit, physics, or bitmap asset production;
- stored combat state on `Quest`;
- delayed delete or retry transitions;
- new notification behavior;
- new widget behavior;
- achievement systems, loot, combo counters, or persistent battle logs;
- changing mob level or importance formulas.

## UX Requirements

### Completion Flow

Pending quest rows must follow this sequence when completion is triggered:

1. close any revealed action rail;
2. enter a resolving state immediately;
3. disable edit, delete, and repeat completion for that row;
4. show a hit phase for the first part of the delay;
5. show a defeated or victory phase before the row leaves;
6. call the completion callback exactly once after the delay;
7. allow the existing pending list animation to remove the row after the fact mutation.

The row should not vanish at the moment the user taps the complete action.
The delay should be short enough to feel responsive.
The initial target is `0.82` seconds, with the defeated phase beginning at `0.34` seconds.

### Visual Treatment

The battle feedback should remain SwiftUI-native and restrained:

- the monster glyph may scale, rotate, or change opacity;
- the row title may dim during the defeated phase;
- a compact `VICTORY +1` badge may appear on the right side of the row;
- the row should not expand vertically during the transition;
- the row should not use large overlays that hide neighboring quests.

### Accessibility

While resolving, the row should expose that completion is in progress through its accessibility label or value.
The complete and delete accessibility actions should not fire while resolving.
The implementation should not rely only on color to show the transition.

## Architecture

Keep the current lifecycle owner:

```plaintext
SwipeableQuestRow
  -> captures completedAt at user action time
  -> plays row-local transition
  -> calls onComplete(quest, completedAt)
  -> ContentView.complete(quest, at: completedAt)
  -> QuestActions.complete
  -> widget snapshot write
  -> notification cancel
```

Add one pure transition policy:

```plaintext
QuestBattleResolution
  -> commitDelay
  -> defeatedPhaseDelay
  -> phase(elapsed:)
  -> shouldAcceptCompletion(isResolving:)
```

`SwipeableQuestRow` owns only transient UI state.
`QuestRow` renders the current `QuestBattlePhase`.
`ContentView` remains the only place that mutates quest facts, writes widget snapshots, and cancels notifications.

## Data And State Rules

Do not add fields to `Quest`.
Do not store battle phase, victory animation state, or action rail state in SwiftData.
Do not change notification identifiers or widget payload shape.
Do not mark a quest complete before the row transition finishes, but do preserve the captured action timestamp when writing `completedAt`.
Do not allow a resolving row to call completion more than once.

## Testing Requirements

Automated tests must cover:

- transition phase boundaries before hit, during hit, and after defeated threshold;
- the commit delay value remains short and positive;
- resolving rows reject repeated completion attempts at the policy layer;
- `QuestActions.complete` still records the explicit completion timestamp;
- existing notification and widget tests continue passing through the unchanged lifecycle.

Final verification commands:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Manual verification should include:

- create a pending quest with a future deadline;
- reveal the leading complete action rail;
- tap complete and confirm the row stays visible briefly;
- confirm the row shows battle feedback and then disappears;
- confirm repeated taps during the transition do not duplicate completion;
- confirm trailing delete still works for non-resolving rows;
- confirm `내일 도전하기` still works for daily graves.

## Acceptance Criteria

- Completing a pending quest by swipe shows a short row-level battle transition before the row leaves.
- The completion fact uses the captured user action time.
- Completion callback fires exactly once per resolving row.
- Delete, retry tomorrow, edit, notification cancellation, and widget snapshot behavior still work.
- `Quest` remains raw facts only.
- No third-party dependency is added.
- `QuestKeeperTests` pass on the `iPhone 17e` simulator.
- The app builds for the `iPhone 17e` simulator.
