# Hall of Fame

Tracked as Linear AND-112.

## Goal

Tapping the HUD victory counter opens a shame-free view of the user's current on-time completions.
The screen reinforces a small success without adding a second history store.

## Current-State Semantics

A Hall of Fame entry is a current Quest whose `QuestSnapshot.outcome(at: now)` is `.victory`.
This is the same on-time completion predicate that produces `HeroState.totalVictories`.
Late completions remain graves and do not appear.
The view derives entries from the current Quest store on every update.
If a Quest is deleted or stops being a victory, its entry disappears immediately.
No archive, migration, or new persisted model exists in this version.

Entries sort by `completedAt` from newest to oldest.
Equal completion instants sort by `UUID.uuidString` in ascending order so the result is deterministic.
Each eligible Quest appears exactly once.

## Presentation

The existing victory counter becomes the entry button in both `HeroHeader` `ViewThatFits` layouts.
It presents `HallOfFameSheet` through the existing local `HomeDungeonSheet` enum.
The sheet owns only dismissal and wraps its content in `NavigationStack`.

The populated sheet has a localized title, the existing trophy artwork, and a vertically scrollable list of Quest titles.
Rows are read-only in this version.
No per-row date, details, edit action, delete action, or new pixel art is required.
A long title wraps instead of clipping.

The empty state says that completed quests will appear here.
It must not describe the user as failing or missing anything.

## Accessibility And Localization

The HUD button has its own localized accessibility label, hint, and stable identifier.
The sheet heading and every Quest title remain individually discoverable by accessibility.
The button keeps a 44-point minimum tap target without expanding the HUD layout.

All new copy is declared through `AppStrings` with Korean as the default value and an English catalog value.
The Korean and English sheet must render at default and large Dynamic Type without clipped headings, buttons, or long titles.

## Non-Goals

- Persisting a permanent victory archive after a Quest is deleted or uncompleted.
- Changing `Quest`, `QuestSnapshot`, widget payloads, retention models, or migrations.
- Showing late completions, individual Quest details, or Quest actions from the sheet.
- Adding another navigation router, view model, dependency, or artwork set.

## Verification

- A focused `HallOfFameState` test proves victory membership, deterministic newest-first ordering, and removal when the current facts no longer describe a victory.
- A UI test opens the sheet from the HUD, checks populated and empty states, and confirms a fixture's long title has a non-clipped frame.
- `bash scripts/test-localization.sh` validates catalog coverage.
- The targeted Hall of Fame tests and the full `QuestKeeperTests` suite pass with parallel testing disabled.
- A simulator pass reads the Korean and English views at default and large Dynamic Type.
