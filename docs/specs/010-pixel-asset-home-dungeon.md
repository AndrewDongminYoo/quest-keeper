# Spec 010 — Pixel Asset Home Dungeon

Status: awaiting written-spec review
Depends on: 007 (home dungeon board), 008 (row battle transition)
Tracks: AND-42

## Goal

Replace the home dungeon's code-drawn placeholder sprites and selected SF Symbols with an original, cohesive pixel-art asset set generated through `imagegen`.
The result should make each quest read as a small battle while preserving QuestKeeper's existing raw-facts model, SwiftUI interaction structure, and forgiving product voice.

## Product Decision

Generate one cohesive sprite sheet, review that sheet before any extraction, and only split approved artwork into project assets.
The linked Quest app article is interaction and mood reference only.
QuestKeeper must not copy that application's layouts, characters, sprites, colors, or other protected expression.

The approved first pass covers the home dungeon and its core state feedback.
Categories, inventory, persistent character levels, and a completed-log screen remain outside this work.

## Reference Principles

The reference article contributes four product principles:

- a task can be represented as a monster;
- completing a task can read as defeating that monster;
- visible victory feedback can reinforce motivation;
- a restrained retro-game presentation can make a todo surface feel playful.

Current project authority remains `BLUEPRINT.md` for product and state rules and `DESIGN.md` for visual direction.
When the reference conflicts with those documents, the project documents win.

## Scope

In scope:

- generate an original sprite sheet containing the home dungeon's required characters and state markers;
- show the unsplit generated sheet to the user and wait for explicit approval;
- remove the flat chroma-key background only after approval;
- split approved artwork into individual transparent PNG assets;
- add the final assets to the app asset catalog;
- replace the home HUD hero placeholder;
- replace the quest-row monster placeholders for low, medium, and high mob tiers;
- replace the daily-grave placeholder with a pixel-art marker;
- replace the compact victory reward placeholder with pixel-art feedback where it fits without changing row height;
- preserve light mode, dark mode, Dynamic Type, VoiceOver, and Reduce Motion behavior;
- record the final generation prompt and generated asset inventory in the project.

Out of scope:

- copying the reference application's screen composition or assets;
- SpriteKit or SceneKit;
- new task categories;
- item inventory or equipment systems;
- stored hero level, experience, or combat state;
- a new completed-log screen;
- changes to mob-level derivation, urgency, importance, daily-grave rules, notifications, or widget payloads;
- redesigning sheets, forms, permission prompts, or settings screens;
- adding a bitmap font.

## Asset Set

The first sheet should contain:

- hero idle;
- hero mourning;
- low-tier slime;
- medium-tier skeleton;
- high-tier dragon;
- daily-grave marker using the established `(+)` motif without introducing a permanent grave counter;
- coin or star victory reward;
- compact victory stamp or impact effect.

The artwork should use a consistent pixel grid, outline weight, viewing angle, and dungeon-at-night palette.
It should remain legible at the existing approximate render sizes of `20` points for the HUD hero and `30` points for row monsters.
The sheet must contain no text, logos, UI chrome, copied characters, or scenery from the reference application.

## Image Generation And Review Gate

Use the built-in `imagegen` path.
Generate the sprite sheet on a flat chroma-key background selected to avoid the subject palette.
Because the slime may use green, prefer magenta `#FF00FF` over green for the key color.

The workflow is binding:

1. generate one unsplit source sheet;
2. inspect it for subject coverage, consistency, unwanted text, copied visual expression, and cell separation;
3. present the unsplit sheet to the user;
4. wait for explicit approval;
5. if rejected, generate or edit one targeted revision and repeat the review gate;
6. only after approval, copy the approved source into the workspace, remove the key color, and split it;
7. validate transparency, edge quality, cell bounds, and nearest-neighbor scaling;
8. add only the approved final assets to the asset catalog.

No cropping, chroma-key removal, per-sprite export, or application integration may occur before the user approves the unsplit source sheet.

## SwiftUI Integration

Introduce one small asset-backed sprite view or extend the existing sprite presentation seam if that produces the smaller diff.
The view should render asset images with nearest-neighbor interpolation and a stable frame.
Decorative images should be hidden from accessibility when adjacent text already communicates the state.
Meaningful images should preserve the existing accessibility labels such as mob level and mourning state.

Replace only the current visual placeholders:

```plaintext
HeroHeader
  -> approved hero asset

MonsterGlyph
  -> mob level 0...1: slime asset
  -> mob level 2...3: skeleton asset
  -> mob level 4...5: dragon asset

DailyGraveRow
  -> approved daily-grave asset

QuestRow battle feedback
  -> approved victory reward or impact asset
```

Do not change the ownership of `QuestBattlePhase` or other transient UI state.
Do not add asset names, monster types, or animation state to `Quest` or SwiftData.
Do not resize rows while an image changes state.

## Motion And Accessibility

Reuse the existing scale, rotation, opacity, and battle-phase transitions where they remain appropriate for the approved sprites.
When Reduce Motion is enabled, use opacity or immediate state replacement instead of travel, impact, or exaggerated scaling.
Do not rely on sprite color alone to distinguish mob level, victory, or mourning.

Test at an accessibility text size large enough to exercise multiline quest titles.
The sprite column must not compress the title and countdown beyond legibility.

## Failure Handling

If the generated sheet contains inconsistent subjects, merged cells, text, signatures, or visual copying, reject it before extraction and revise the prompt once with a targeted correction.
If chroma removal leaves visible fringe, retry local removal with a one-pixel edge contraction before considering another generation.
If a sprite becomes unreadable at its in-app size, prefer simplifying that sprite or increasing its fixed frame slightly without changing row height.
Do not add a new image-processing dependency for extraction or cleanup.

## Verification

Automated verification:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Manual simulator verification:

- launch the app with an empty dungeon and confirm the primary action remains clear;
- create quests that render low-, medium-, and high-tier monsters;
- confirm the HUD hero and all monster tiers remain crisp in light and dark mode;
- complete a quest and observe the approved victory feedback without row-height change;
- inspect a newly missed quest and an older daily grave;
- retry a daily grave tomorrow and confirm the existing lifecycle still works;
- test a multiline Korean quest title at a large accessibility text size;
- enable Reduce Motion and confirm battle feedback uses a restrained state change;
- confirm VoiceOver communicates quest title, countdown, mob level, and actions without reading decorative filenames.

## Acceptance Criteria

- The user approved the unsplit generated sprite sheet before extraction.
- The home dungeon uses original approved image assets for the hero, three mob tiers, daily grave, and victory feedback.
- The final assets are stored in the project and are not referenced from a temporary or global generated-image path.
- Generated artwork does not copy the referenced application's characters, sprites, layout, or branding.
- Quest row height and existing actions remain stable.
- `Quest` continues to persist raw facts only.
- No third-party dependency is added.
- `QuestKeeperTests` pass on the selected simulator.
- The app builds and the required states are manually observed in the iOS Simulator.
