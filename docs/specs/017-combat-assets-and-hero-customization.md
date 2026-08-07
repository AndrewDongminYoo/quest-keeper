# Spec 017 - Combat Assets And Hero Customization

Status: approved
Depends on: 008 (row battle transition), 010 (pixel asset home dungeon), 011 (pixel UI icons and hero animation)
Blocks: none

## Goal

Make the daily dungeon feel visibly alive by expanding monster variety, showing the hero and monster together during quest completion, and allowing lightweight hero appearance choices.
Preserve QuestKeeper's raw-facts model, compact quest rows, forgiving tone, accessibility behavior, and existing completion lifecycle.

## Problem

The current app has three monster artworks selected only by mob-level band.
The hero breathes through three frames, but it remains a small HUD glyph and does not appear in the row battle transition.
Completing a quest currently scales and rotates the monster around one impact asset, so the intended sword swing and combat scene are not clearly visible.
The hero has one fixed appearance and offers no user-selected identity settings.

## Product Decision

Extend the current PNG asset catalog and SwiftUI transition architecture.
Do not introduce SpriteKit, SceneKit, a reusable animation engine, or a runtime image-processing dependency.
Use original QuestKeeper pixel art and fixed frame sequences so the feature remains deterministic, testable, and compatible with the current rendering seam.

## Scope

In scope:

- expand the monster catalog from three to nine original monsters;
- keep three monster families per derived mob-level band;
- select a stable family member from the quest identifier without persisting monster type;
- display the selected monster consistently in the app and widget;
- add male-presenting and female-presenting hero artwork;
- add black, brown, blue, and red hair choices;
- preserve the current male-presenting blue-haired hero as the default appearance;
- add visible hero wind-up and sword-strike frames;
- show the hero, monster, strike, impact, and defeated states inside one fixed-size row battle stage;
- add a native hero appearance sheet opened from an explicit HUD action;
- persist only the user-selected appearance preferences in app preferences;
- preserve Dynamic Type, VoiceOver, Reduce Motion, light mode, and dark mode;
- record approved source sheets, checksums, extraction boundaries, and palette-replacement decisions.

Out of scope:

- inventory, unlocks, achievements, currencies, shops, rarity, or monetized skins;
- hero names, skin tone, armor selection, weapons, classes, or body sliders;
- persistent combat logs, HP, damage numbers, combos, or stored monster identity;
- changing quest deadlines, outcomes, importance, notifications, daily focus, recovery, or widget intent behavior;
- moving the hero around the home screen outside the row battle stage;
- SpriteKit, SceneKit, physics, path finding, or a general sprite animation framework;
- a broad navigation or settings redesign;
- new third-party dependencies.

## Monster Catalog

The approved catalog contains nine monsters arranged by visual threat.

| Mob level | Family        | Monsters             |
| --------- | ------------- | -------------------- |
| `0...1`   | low threat    | slime, bat, mushroom |
| `2...3`   | medium threat | skeleton, orc, mimic |
| `4...5`   | high threat   | dragon, golem, lich  |

Level determines the family.
The quest identifier determines the member within that family using a stable, process-independent reduction over UUID bytes.
Swift's randomized `hashValue` must not be used.

The mapping is visual only.
Do not add monster type, family, seed, artwork name, or animation state to `Quest`, `QuestSnapshot`, SwiftData, daily focus state, notification payloads, or retention events.
Every monster sprite faces left toward the right-facing hero so the row battle stage reads as an encounter rather than two unrelated icons.

The widget must use the same pure selection policy so a quest displays the same monster in both surfaces.
The selected artwork must remain stable across launches and device restarts.

## Hero Appearance

### Options

The first appearance baseline contains:

- gender presentation: `male` and `female`;
- hair color: `black`, `brown`, `blue`, and `red`.

The user-facing labels are `남성형`, `여성형`, `검정`, `갈색`, `파랑`, and `빨강`.
These choices describe artwork presentation only and do not affect quest rules, combat strength, rewards, copy, or accessibility meaning.

The default is `male` plus `blue` so existing installations retain the current visual identity when no preference has been stored.
Unknown stored raw values must fall back to that default without crashing.

### Persistence

Store the two selections in app preferences through `AppStorage`-compatible raw string keys.
Centralize the keys and typed decoding in the appearance model so views do not repeat string literals or fallback rules.
Do not add appearance fields to `Quest`, `HeroState`, `HeroDerivation`, SwiftData, widget payloads, or CloudKit schema.

The app HUD and row battle scene consume the same appearance value.
The widget does not show the hero and therefore does not receive appearance preferences.

### Settings Sheet

Add an explicit `외형` action to the HUD with a minimum 44-point hit target.
The action opens a native SwiftUI sheet containing:

- a large live hero preview;
- a gender presentation picker;
- a hair-color picker;
- a `완료` dismissal action.

The preview uses the breathing sequence when Reduce Motion is disabled and a stable idle frame when it is enabled.
Changing either picker updates the preview and HUD immediately.
The sheet must support compact width, large Korean accessibility text, VoiceOver, light mode, and dark mode without replacing standard picker semantics.

## Hero Asset Model

Each gender presentation has five authored source frames:

1. idle;
2. breathe in;
3. breathe out;
4. attack wind-up;
5. attack strike.

All frames preserve the same armor, sword, viewing angle, apparent scale, foot baseline, and horizontal center within one gender presentation.
Gender presentations may differ in face and hair silhouette, but they use the same armor, weapon, palette family, outline weight, and animation timing.

Author the hair with a small documented source palette that can be deterministically replaced during asset preparation.
Generate the four hair-color outputs from the ten approved source frames instead of asking the image generator to redraw forty independent variants.
Committed runtime PNG files are final build inputs and require no runtime image processing.

The output naming contract is:

```plaintext
sprite-hero-<gender>-<hair>-idle
sprite-hero-<gender>-<hair>-breathe-in
sprite-hero-<gender>-<hair>-breathe-out
sprite-hero-<gender>-<hair>-wind-up
sprite-hero-<gender>-<hair>-strike
```

The existing generic hero names may remain only until every app call site has migrated and asset-name tests cover the new catalog.
Remove newly orphaned hero assets after migration, but do not remove unrelated pre-existing assets.

## Asset Generation And Approval Gate

Use the built-in image generation path with the current approved QuestKeeper hero and monster sheet as identity and style references.
Generate two unsplit source sheets:

1. a three-by-three monster sheet containing the exact nine-monster catalog;
2. a two-row hero sheet containing the five male-presenting frames and five female-presenting frames.

Both sheets must use a flat chroma background outside the subject palette, fixed equal cells, uniform safe margins, crisp nearest-neighbor pixel edges, and no text, logos, shadows, gradients, scenery, signatures, watermarks, detached particles, or subjects crossing cell boundaries.
The monster sheet must preserve the existing slime, skeleton, and dragon identities while adding six original QuestKeeper monsters.
All nine monsters must use a left-facing or left-biased three-quarter pose while preserving their silhouettes and equipment.
The hero sheet must preserve the current male-presenting hero identity in its default idle frame and keep both hero presentations coherent across all five poses.

The workflow is binding:

1. generate both unsplit sheets;
2. inspect subject count, order, identity, pose continuity, silhouette readability, safe margins, background uniformity, and unwanted content;
3. present both unsplit sheets to the user;
4. wait for explicit approval;
5. if rejected, perform a targeted edit or regeneration and repeat the approval gate;
6. only after approval, copy the approved sources into a temporary workspace and extract cells without resampling opaque pixels;
7. generate hair-color variants from the documented hair palette;
8. validate dimensions, alpha, nonempty bounds, foot baselines, centers, palette mapping, and asset manifests;
9. integrate only approved final assets into target-specific catalogs.

No cell extraction, hair recoloring, asset-catalog integration, or Swift implementation may use an unapproved source sheet.

## Artwork Selection Architecture

Replace the level-only monster mapping with one pure selection seam:

```plaintext
MonsterArtworkSelection
  -> family(forMobLevel:)
  -> variantIndex(forQuestID:)
  -> artwork(forMobLevel:questID:)
```

The app and widget may expose target-local artwork enums, but both consume the same shared family and variant-index policy.
Keep bundle-specific names explicit because the app and widget compile separate asset catalogs.

Add one typed hero appearance and frame seam:

```plaintext
HeroAppearance
  -> gender
  -> hairColor

HeroAnimation
  -> idle breathing frame
  -> battle frame
  -> target artwork name
```

Do not create a generic asset registry, animation protocol hierarchy, plugin system, or scene graph.
The fixed catalogs and two pure selection seams are sufficient for this feature.

## Row Battle Scene

### Phases

Extend the row-local transition to these visual phases:

```plaintext
idle -> windUp -> striking -> defeated
```

The total delay should be approximately one second and must remain short enough that completing several quests does not feel blocked.
The exact thresholds are centralized in `QuestBattleResolution` and protected by unit tests.

The recommended baseline is:

- wind-up begins immediately and lasts approximately `0.18` seconds;
- strike and impact last until approximately `0.42` seconds;
- the defeated and reward state remains visible until approximately `1.05` seconds;
- the completion callback fires once after the final delay.

The callback receives the action timestamp captured before the animation begins.
Do not derive `completedAt` from the delayed commit time.

### Layout

During battle, replace only the row's trailing monster presentation with a fixed `100x48` point battle stage.
The stage shows the hero on the left and the monster on the right.
The hero faces right and every monster faces left toward the hero.
It must not change the row's minimum height, title width allocation, neighboring row position, or scroll offset.

The visual sequence is:

1. wind-up frame with the hero planted on the left;
2. strike frame with a short horizontal lunge and sword arc;
3. impact artwork between the hero and monster;
4. monster recoil followed by the defeated state;
5. the existing victory reward and label before row removal.

Motion must communicate the completion state rather than run decoratively while idle.
The HUD breathing sequence remains the only repeating animation.

### Reduce Motion

When Reduce Motion is enabled:

- do not translate, rotate, scale, or spring the hero or monster;
- switch directly between wind-up, strike, and defeated frames at the same semantic phase boundaries;
- keep the impact artwork and victory label visible;
- preserve the same completion timestamp and callback delay;
- do not rely on motion or color alone to communicate progress.

### Interaction And Lifecycle

Keep `SwipeableQuestRow` as the transient lifecycle owner.
Capture the completion timestamp at the first accepted action.
Reject complete, delete, edit, and additional swipe actions while the row is resolving.
Cancel the battle task when the row identity changes or the view disappears.
Call the existing completion closure exactly once.

Do not move quest mutation, widget writes, notification cancellation, or retention recording into the battle view.

## Accessibility

The hero keeps the accessibility meaning `용사` or `쓰러진 용사` independent of gender, hair color, or animation frame.
The appearance sheet must expose selected gender presentation and hair color through native picker values.
Decorative image layers and sword effects must not announce asset filenames.

While resolving, the row exposes `공격 준비 중`, `공격 중`, or `승리 처리 중` as its accessibility value.
The monster label includes its localized monster name and level rather than only `몹 레벨 N`.
The completion action remains unavailable while resolving.

## Failure Handling

Reject a source sheet before extraction if subject order is wrong, a required subject is missing, an existing character changes identity, poses cannot be distinguished at target size, a subject crosses a cell boundary, or the source contains text, signatures, merged cells, shadows, gradients, scenery, or copied expression.
Prefer a targeted edit when one cell is defective and the remaining sheet is coherent.

If chroma removal leaves a fringe, correct the extraction locally without resampling the subject.
If a hair palette pixel is ambiguous with skin, armor, outline, or background pixels, revise the approved source palette before generating variants.
Do not mask the ambiguity with a broad hue replacement.

Unknown stored appearance values fall back to the default appearance.
Missing or misspelled runtime asset names are test and build failures, not silent fallbacks.

## Testing

Follow red-green-refactor for each behavior boundary.

Focused automated coverage must prove:

- every mob level maps to the correct three-member family;
- UUID reduction is stable and reaches all three family variants;
- the same mob level and quest identifier select the same app and widget monster identity;
- all nine monster artwork names are unique and present in the required target catalogs;
- appearance decoding defaults unknown values to male-presenting blue hair;
- all eight gender and hair combinations resolve to five distinct required frames;
- breathing and battle frame order is deterministic;
- battle phase boundaries cover idle, wind-up, striking, and defeated;
- completion still accepts one action and rejects repeats while resolving;
- the explicit action timestamp remains the stored completion time;
- all generated hero PNG files have matching dimensions, valid alpha, nonempty subjects, and aligned baselines.

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
```

## Manual Verification

Use the iPhone 17e simulator and observe the real app surface.

Verify:

- the default HUD preserves the current male-presenting blue-haired appearance;
- the enlarged hero completes multiple visible breathing cycles without baseline jitter;
- the `외형` action opens the sheet and both pickers update the preview immediately;
- all eight appearance combinations display correctly and persist after relaunch;
- a low-, medium-, and high-level quest can display each catalog family without changing quest facts;
- the same quest displays the same monster after relaunch and in its widget presentation;
- completing a quest visibly shows wind-up, sword strike, impact, monster recoil, victory, and row removal;
- repeated completion attempts do not duplicate the completion;
- the battle stage does not resize the row or move neighboring content;
- Reduce Motion uses static semantic frame changes without travel, rotation, scale, or spring motion;
- light mode, dark mode, large Korean accessibility text, and VoiceOver remain usable;
- delete, edit, retry tomorrow, notifications, daily focus, recovery, and widget completion still work.

Capture fresh rest, mid-transition, and settled screenshots for the HUD, appearance sheet, and battle scene after the final source edit.
Independent visual QA must inspect every captured state before completion is claimed.

## Acceptance Criteria

- The user explicitly approved both unsplit source sheets before extraction and integration.
- The app and widget expose nine original monsters with stable, derived selection and no stored monster identity.
- The app supports two gender presentations and four hair colors with the current hero as the default.
- Appearance choices persist through app preferences without changing Quest, HeroState, SwiftData, or widget payloads.
- The HUD breathing animation is visibly readable and stable.
- Completing a quest shows the hero wind up, swing a sword, hit the monster, and reach a victory state before row removal.
- Reduce Motion communicates the same states without travel, rotation, scale, or spring motion.
- Existing completion timestamps, notification cancellation, widget synchronization, daily focus, recovery, delete, edit, and retry behavior remain intact.
- No third-party dependency or general animation engine is added.
- QuestKeeper unit tests pass and both app and widget schemes build for the iPhone 17e simulator.
- Fresh simulator captures pass independent visual and CJK review.
