# DESIGN — QuestKeeper

Visual and UX direction for the post-BLUEPRINT pivot.
`BLUEPRINT.md` owns product rules; `docs/specs/` owns implementation contracts.
This file owns how the app should feel and look.

## Thesis

A **daily pixel dungeon for small wins**.

QuestKeeper is no longer a quiet native ledger with one decorative hero stage.
The root screen is the game board: each quest is a dungeon floor, each deadline is a monster, and each small completion is a one-hit victory.
The tone is playful and forgiving, not punitive.
Missed quests can look dramatic for a moment, but yesterday's failures must not become a permanent monument.

The product promise:

- imperfect days still count;
- small wins are visually louder than misses;
- failed quests can be retried tomorrow without shame;
- all game state remains derived from raw facts.

## Screen Model

The first viewport is a full-screen vertical dungeon.
Do not make a marketing page, dashboard card grid, or native settings-style list as the primary surface.

```plaintext
QUEST KEEPER
HERO: Leo | VICTORIES: 13

[floor] Review BLUEPRINT.md                 LEVEL 1  [slime]
[floor] Refactor HeroDerivation             [daily grave + retry tomorrow]
[floor] Implement Swipe Actions             3H LEFT  LEVEL 5  [dragon]
[guide] "Month-long quest? Chunk it, hero!"
[floor] Did One Pushup                      completed + coins

[tab bar] log / sword / dungeon / settings
```

The reference image is a direction, not a literal asset spec.
Keep the information architecture tight: one quest row per dungeon floor, compact HUD, bottom navigation only if it earns its place.

## Emotional Rules

- **Wins persist emotionally.** Completed quests create coins, stamps, stars, and the victory count.
- **Failures are temporary pressure.** A missed quest can show a tombstone or defeated hero only in today's dungeon window.
- **Retry is first-class.** "내일 도전하기" should feel like a normal recovery action, not a failure workaround.
- **The elder guide is protective.** Long or oversized quests trigger chunking advice with humor and care.
- **No shame copy.** Avoid notification or UI text that says the user failed as a person.

## Visual Language

### Pixel Dungeon

Use pixel-art language for the primary surface:

- stone floor lanes;
- torch edges;
- small hero / monster sprites;
- chunky pixel borders;
- coin/star/completed stamp effects;
- compact speech-box overlays for advice.

This does not require complex SpriteKit animation in the first pass.
SwiftUI views, image frames, SF Symbols placeholders, and simple transitions are acceptable until real assets exist.

### Native iOS Restraint

The app may be game-like, but it still runs on iOS:

- forms, permission affordances, sheets, and settings links should remain SwiftUI-native;
- text must respect Dynamic Type as much as the pixel style allows;
- destructive or confusing actions need clear labels;
- avoid custom controls where standard iOS controls carry the interaction better.

## Color

Use a dungeon-at-night palette with state-driven accents.
Avoid a one-note brown/orange screen; the dungeon can be dark, but state colors must be legible.

| Token | Light | Dark | Meaning |
| --- | --- | --- | --- |
| `ink` | `#17151D` | `#F2EDF7` | Primary text |
| `dungeon` | `#2B2735` | `#17131F` | Main background |
| `stone` | `#6E7485` | `#414758` | Floor tiles |
| `torch` | `#F2A03D` | `#FFB14A` | Warm dungeon light |
| `hero` | `#3A73D9` | `#6FA0FF` | Hero / primary action |
| `victory` | `#F4C542` | `#FFD95A` | Coins, stars, completed state |
| `danger` | `#D9573F` | `#FF705A` | Urgency and high-level monsters |
| `grave` | `#8B9290` | `#A5AAA8` | Today's missed quest marker |
| `guide` | `#5CC9B5` | `#7FE0D0` | Elder guide / safe advice |

Accent colors carry meaning only.
Do not add decorative glow blobs or gradients as filler.

## Type

Use system fonts until a licensed bitmap font is chosen.

- **Title / HUD:** monospaced or rounded bold system font, uppercase allowed for compact game HUD labels.
- **Quest title:** legible body text; Korean and English titles must not wrap awkwardly inside a row.
- **Counters and countdowns:** monospaced digits.
- **Advice box:** compact, high-contrast body text; do not make tutorial prose visible unless the guide is actively speaking.

If a bitmap font is introduced later, use it sparingly: title, HUD labels, and stamps only.
Do not sacrifice readability for the costume.

## Core Components

### HUD

The HUD shows the minimum daily context:

- app title;
- hero name or label;
- total victories;
- optionally today's active quest count.

Do not show HP.
Do not show permanent grave count.

### Quest Floor Row

A quest row is a dungeon floor:

- left or center: quest title;
- right: monster sprite and level;
- secondary line: countdown;
- state overlay: completed stamp, daily grave marker, or retry action.

Rows must stay stable in height.
Animations and labels cannot resize the list as the countdown changes.

### Monsters

Monster strength is visualized from derived `mobLevel`.
Default mapping:

```plaintext
0-1: slime / tiny mob
2-3: skeleton / normal mob
4-5: dragon / giant mob
```

This mapping is visual only.
Do not store monster type on `Quest`.

### Daily Grave

A missed quest may show:

- tombstone;
- defeated hero frame;
- muted title;
- "내일 도전하기" action.

The daily grave is a derived presentation, not a permanent archive item.
It should disappear from the main dungeon after the configured daily window or after retrying tomorrow.

### Elder Guide

The elder guide appears when the user creates or edits a quest with a deadline beyond the chunking threshold.
Default threshold: `GameBalance.longQuestWarningHorizon` (7 days).

The guide offers two actions:

- listen to advice / split smaller;
- proceed anyway.

The guide is not an LLM feature in Phase 2.
It is a fixed, local SwiftUI alert/sheet with product voice.

## Motion

Keep the first implementation simple:

- swipe complete: monster hit / completed stamp / coin burst;
- deadline miss on activation: brief "꿱" frame or tombstone transition;
- retry tomorrow: tombstone lifts or row resets into active floor;
- chunking guide: speech-box transition.

Respect Reduce Motion.
If Reduce Motion is enabled, swap to opacity/state changes without travel or impact motion.

## Voice

Korean UI is the default.
Quest-flavored but plain.

Use:

- `전투 추가`
- `내일 도전하기`
- `완료`
- `3시간 남음`
- `너무 큰 퀘스트예요. 작게 쪼개볼까요?`

Avoid:

- `실패했습니다`
- `무덤이 누적되었습니다`
- `HP가 감소했습니다`
- `오늘도 못 했네요`

## Deliberately Avoided

- permanent failure graveyard as the primary emotional hook;
- HP bars or stored health;
- a separate analytics dashboard for shame metrics;
- full SpriteKit dependency for MVP;
- complex recurring quest engine;
- LLM chunking in Phase 2;
- visual polish that requires storing derived state.

## Adoption Order

1. Reconcile derivation with daily graves and total victories.
2. Add "내일 도전하기" and chunking guide in the current SwiftUI screen.
3. Replace the native list surface with the pixel dungeon shell.
4. Add simple completion/miss/retry transitions.
5. Replace placeholder symbols with real pixel sprites.
