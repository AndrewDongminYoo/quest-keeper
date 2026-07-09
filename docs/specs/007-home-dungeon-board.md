# Spec 007 — Home Dungeon Board

Status: planned
Depends on: 006 (integration verification), merged Phase 5 branch
Blocks: home-screen visual identity pass

## Goal

Replace the native default home `List` surface with a full-screen SwiftUI dungeon board that makes today's quests easier to scan while keeping the existing quest facts, notification lifecycle, retry tomorrow flow, and widget snapshot behavior unchanged.

## Problem

The current home screen is functionally correct, but it still reads like a standard SwiftUI todo list:

- the root surface is `NavigationStack` plus `List` plus `Section`;
- pending quests are plain rows with a title, gray countdown, small level badge, and SF Symbol monster;
- daily graves sit in another native section;
- the primary add action is a default toolbar item;
- the dungeon concept is mostly copy and palette, not the first visual signal.

This weakens the product direction in `DESIGN.md`, which says the first viewport should be a full-screen vertical dungeon rather than a native settings-style list.
The next implementation should make the home screen feel like QuestKeeper without expanding gameplay scope.

## Product Decision

Build a **SwiftUI dungeon board**, not a full game engine.

The first pass should use SwiftUI layout, colors, SF Symbols, monospaced HUD text, and simple shape styling.
It should not introduce SpriteKit, bitmap asset production, bottom tabs, stored visual state, or new gameplay mechanics.

## Scope

In scope:

- replace the root home `List` with `ScrollView` plus `LazyVStack`;
- keep the same create, edit, complete, retry tomorrow, delete, notification, activation replay, and widget snapshot flows;
- turn `HeroHeader` into a board HUD area or place it inside a board shell;
- render pending quests as stable-height dungeon floor rows with stronger title, deadline, importance, level, and monster hierarchy;
- render daily graves as stable-height recovery rows where `내일 도전하기` remains visible and first-class;
- add a more intentional empty dungeon state inside the board;
- add small pure presentation helpers where needed so row text and urgency are testable without UI automation;
- keep Korean user-facing strings intentional.

Out of scope:

- new `Quest` stored fields;
- permanent graveyard or archive;
- HP bars or stored health;
- recurring quests;
- new notification behavior;
- new widget behavior;
- real pixel-art bitmap assets;
- SpriteKit or SceneKit;
- bottom navigation;
- drag gestures, custom physics, or combat animation.

## UX Requirements

### First Viewport

The first viewport must show:

- a compact `QUEST KEEPER` HUD;
- hero/victory context;
- an obvious add action;
- today's pending quests and daily graves as dungeon rows when they exist;
- a themed empty dungeon state when there are no pending quests or daily graves.

The screen should not look like a grouped settings list.
Native sheets and alerts may remain native.

### Quest Rows

Pending quest rows must:

- preserve tap-to-edit;
- preserve leading swipe completion;
- preserve trailing swipe deletion;
- show the quest title with stronger contrast than the countdown;
- cap the title at two lines;
- show the countdown with monospaced digits;
- make urgent deadlines visually louder than distant deadlines;
- show mob level and monster glyph without storing monster type;
- keep row height stable enough that countdown changes do not jump the layout.

Daily grave rows must:

- show a muted missed-state marker;
- keep `내일 도전하기` directly visible;
- preserve retry behavior;
- avoid shame copy;
- keep row height stable.

### Empty State

The empty state must be board-native:

- use dungeon/quest language without marketing copy;
- show a clear add affordance nearby;
- avoid a floating card inside another card;
- work when all quests are completed or when there are no quests.

### Accessibility

Rows must remain tappable and swipeable with SwiftUI gestures and expose the same completion/deletion actions through accessibility actions.
Text should remain readable under Dynamic Type within a reasonable range.
The implementation may use fixed minimum row heights, but must not clip Korean quest titles in normal accessibility sizes.

## Architecture

Keep the current data flow:

```plaintext
SwiftData Quest raw facts
  -> TimelineView now
  -> HeroDerivation / QuestSnapshot derivation
  -> ContentView partitions pending and dailyGraves
  -> home board renders derived presentation
```

Add a small home-board presentation layer:

```plaintext
ContentView
  -> HomeDungeonBoardView
      -> HeroHeader
      -> QuestListSections
          -> QuestRow
          -> DailyGraveRow
      -> EmptyDungeonState
```

`HomeDungeonBoardView` owns layout and background.
`QuestListSections` owns pending/daily-grave section composition.
`QuestRow` and `DailyGraveRow` own row visuals.
Pure helpers may live in `QuestKeeper/Views/DungeonPresentation.swift` if they make countdown, urgency, and display text testable.

## Data And State Rules

Do not add derived state to `Quest`.
Do not add notification or widget state to `Quest`.
Do not change `QuestActions`.
Do not change `QuestNotificationService`.
Do not change `WidgetDungeonPayload` behavior.

The board consumes only:

- `[Quest]`;
- `HeroState`;
- `now`;
- existing callbacks from `ContentView`.

## Testing Requirements

Automated tests should cover any new pure presentation helper behavior:

- countdown text for days, hours, minutes, and past-due fallback;
- urgency tone for calm, warning, and danger cases if a helper is introduced;
- no change to raw-facts lifecycle tests.

Final verification commands:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Manual verification should include:

- launch app with empty state;
- create several pending quests with different deadlines;
- confirm the board is more legible than the old native list;
- complete a quest by swiping the custom action rail;
- retry a daily grave with `내일 도전하기`;
- delete a quest by swiping the custom action rail;
- confirm notification and widget lifecycle still behave as before.

## Acceptance Criteria

- `ContentView` no longer uses a root `List` for the primary home board.
- The home screen uses a dungeon board shell with a custom background and stable row bands.
- Quest rows are visibly more scannable than the previous native rows.
- `내일 도전하기`, complete, edit, delete, notification sync, and widget snapshot writes still work.
- `Quest` remains raw facts only.
- No third-party dependency is added.
- `QuestKeeperTests` pass on the `iPhone 17e` simulator.
- The app builds for the `iPhone 17e` simulator.
