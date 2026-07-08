# Spec 003 — Task CRUD & Positive Dungeon UX (Phase 2)

Status: revision planned
Depends on: 002 (data model & daily derivation revision)
Blocks: Phase 3 retry-aware notification lifecycle

Implementation note: the current app implements the pre-pivot native list baseline with `HeroHeader`, Active/Graveyard sections, and notification integration.
This revised spec supersedes that UI target.
The next implementation pass should migrate behavior toward the pixel dungeon screen while keeping the raw-facts-only model.

## Goal

Turn the root screen into a forgiving daily dungeon:

- active quests are monsters on dungeon floors;
- completion is a one-hit swipe victory;
- missed quests become today's temporary grave/defeat presentation;
- "내일 도전하기" moves a quest back into the active dungeon;
- oversized quests trigger a small chunking guide prompt.

This is still a SwiftUI learning phase.
Do not introduce SpriteKit or a new dependency for MVP.

## UX Model

### Dungeon Board

The root view should visually match the new `DESIGN.md` direction:

```plaintext
QUEST KEEPER
HERO: Leo | VICTORIES: 13

[floor] Quest title                 LEVEL N [monster]
[floor] Missed quest                [daily grave] [내일 도전하기]
[guide] chunking advice
[floor] Completed quest             [coins] [COMPLETED]
```

The board may still be built from SwiftUI `List`/`ScrollView` primitives at first.
The important contract is state and interaction, not final pixel polish.

### Active Quests

Active quests are `.pending` snapshots, sorted by urgency / deadline.
Rows show:

- title;
- countdown;
- derived mob level;
- visual monster tier from derived mob level.

Monster type is not stored.

### Daily Graves

Daily graves are `.grave` snapshots that pass `isVisibleDailyGrave(at:)`.
Rows show:

- muted title;
- tombstone or defeated state;
- "내일 도전하기" action.

Older graves are not shown in the main dungeon.
Do not render a permanent Graveyard section on the root screen.

### Victories

On-time completions increment derived `totalVictories`.
The root screen may show a short-lived completed stamp or coin burst, but it does not need a full victory log in Phase 2.

## Required Actions

### 1. Complete

Completion writes `completedAt = now`.
It does not delete the quest.
The action should feel like a one-hit attack:

- swipe / button action;
- quick visual transition;
- completed stamp / coin feedback.

### 2. Retry Tomorrow

Retry tomorrow is a recovery action for visible daily graves.

Action contract:

```swift
QuestActions.retryTomorrow(_ quest: Quest, now: Date, calendar: Calendar = .current)
```

Default behavior:

- set `deadline` to a future time tomorrow;
- set `completedAt = nil`;
- keep `importance`;
- trigger notification resync in Phase 3;
- do not store retry count.

This intentionally mutates a raw fact.
It is not a derived state field.

### 3. Delete

Delete remains a narrow cleanup action for quests the user explicitly wants removed.
Do not use delete as the normal way to recover from a missed quest.

Default:

- pending quests can be deleted;
- victories can be deleted if the user enters an edit/archive surface later;
- visible daily graves should prefer retry tomorrow over delete.

### 4. Chunking Guide

When creating or editing a quest with a deadline beyond `GameBalance.longQuestWarningHorizon`, show the elder guide.

MVP behavior:

- local SwiftUI alert or sheet;
- no LLM;
- no automatic task splitting;
- two choices: proceed anyway, or return to edit smaller.

Example copy:

```plaintext
너무 큰 퀘스트예요.
작게 쪼개면 몹도 작아져요.
```

### 5. Activation Replay

Keep Phase 2's existing state replay ordering:

```plaintext
previous lastOpened -> derive deathsWhileAway -> advance lastOpened
```

The replay drives one temporary "꿱" event.
It must not create stored death records.

## SwiftUI Structure

Target files for the next implementation pass:

- `QuestKeeper/ContentView.swift` — root shell and lifecycle hooks.
- `QuestKeeper/Views/DungeonBoardView.swift` — scrollable dungeon surface.
- `QuestKeeper/Views/DungeonQuestRow.swift` — active quest floor.
- `QuestKeeper/Views/DailyGraveRow.swift` — temporary missed quest row with retry.
- `QuestKeeper/Views/CompletedQuestBurst.swift` — small completion feedback if needed.
- `QuestKeeper/Views/ChunkingGuideView.swift` — elder guide prompt/sheet.
- `QuestKeeper/Actions/QuestActions.swift` — add retry helper.
- `QuestKeeper/Derivation/*` — consume revised `HeroState` from spec 002.

Keep the current `QuestEditor` form unless and until the dungeon visual shell needs a custom editor.
Do not build a separate settings/dashboard screen in Phase 2.

## Tests

Use Swift Testing for behavior seams.
Do not depend on final pixel visuals in unit tests.

1. **Complete writes a fact** — `completedAt` is set and `totalVictories` derives from it.
2. **Retry tomorrow mutates raw facts only** — `deadline` moves future, `completedAt` clears, `importance` remains.
3. **Daily grave partition** — today's grave appears; older grave does not appear in root board input.
4. **Activation replay ordering** — missed quest appears once in `deathsWhileAway` and does not replay after `lastOpened` advances.
5. **Chunking guide trigger** — deadline beyond threshold returns warning-needed; within threshold does not.
6. **No permanent grave count** — root input model does not expose `graves: Int` as a scoreboard.

## Verification

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Manual simulator checks:

```plaintext
1. Create a short quest and complete it.
2. Confirm victory count changes and completed feedback appears.
3. Create or edit a far-future quest.
4. Confirm elder guide appears before save/proceed.
5. Create a near-deadline quest, advance past deadline, reopen.
6. Confirm today's grave appears with "내일 도전하기".
7. Use "내일 도전하기".
8. Confirm the quest returns to active and no permanent grave counter remains.
```

## Out of Scope

- SpriteKit combat engine.
- Real pixel asset production.
- LLM task splitting.
- Recurring quests.
- Permanent graveyard / shame dashboard.
- Widget/App Group changes.

## Open Questions

- Exact retry deadline time: same local time tomorrow vs default evening.
  Default for implementation: same local time tomorrow when possible.
- Whether completed quests remain visible for the rest of the day or only animate briefly.
  Default: brief feedback plus HUD count.
