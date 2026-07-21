# Spec 011 — Pixel UI Icons And Hero Animation

Status: approved
Depends on: 010 (pixel asset home dungeon)
Tracks: AND-44

## Goal

Replace every remaining SF Symbol in the QuestKeeper app and widget with an original pixel-art asset that matches the approved home-dungeon artwork.
Extend the app HUD hero from one idle image to a three-frame breathing cycle without changing layout, persisted facts, game rules, or accessibility meaning.

## Product Decision

Generate one cohesive source sheet containing three hero frames and nine UI icons.
Review the unsplit source sheet before any extraction or integration.
After approval, split the sheet into fixed-canvas transparent PNG assets and integrate only the assets each target uses.

The hero remains a small inline HUD glyph.
This work adds a restrained breathing loop because the hero does not currently travel across the screen.
Walking, path finding, SpriteKit, and a general animation engine remain outside this work.

## Scope

In scope:

- generate three consistent frames for the existing approved hero design;
- generate pixel icons for battle, victory, add, notifications disabled, retry, complete, delete, stale warning, and protection;
- replace all current `Image(systemName:)` and `Label(..., systemImage:)` usage under `QuestKeeper` and `QuestKeeperWidget`;
- reuse one approved asset when the same action appears in more than one view;
- store app assets in `QuestKeeper/Assets.xcassets` and widget assets in `QuestKeeperWidget/Assets.xcassets`;
- preserve the existing labels, actions, button hit areas, row heights, layout priorities, and navigation behavior;
- animate the app HUD hero through a three-frame breathing sequence using view-local transient state;
- show a stable idle frame when Reduce Motion is enabled or the hero is mourning;
- preserve light mode, dark mode, Dynamic Type, VoiceOver, and widget rendering;
- record the approved prompt, source checksum, extraction mapping, and any cleanup decisions.

Out of scope:

- copying the referenced application's characters, icons, layout, palette, or branding;
- moving the hero across the screen;
- walking, attack, or mourning frame sequences;
- SpriteKit, SceneKit, a reusable animation framework, or a new image-processing dependency;
- new actions, state transitions, navigation, widget data, or notification behavior;
- changes to `Quest`, SwiftData, derivation rules, or widget payloads;
- broad visual redesign outside direct icon replacement.

## Approved Asset Inventory

The unsplit sheet contains exactly twelve cells in a strict four-column by three-row grid:

1. hero idle neutral;
2. the same hero at a subtle inhale pose;
3. the same hero at a subtle exhale pose;
4. battle flag;
5. victory trophy;
6. add marker;
7. notifications-disabled bell;
8. retry marker;
9. completion mark;
10. delete marker;
11. stale-warning marker;
12. protection shield.

All hero frames must preserve the approved hero's clothing, hair, proportions, palette, outline weight, viewing angle, and apparent canvas center.
Only the torso height, shoulder position, cape or clothing pixels, and similarly small pose details may change.
The feet and horizontal center should remain anchored so the HUD does not jitter.

All icons must remain recognizable at approximately `12` to `20` points.
They should use chunky silhouettes, dark charcoal outlines, and the existing dungeon-at-night palette rather than depending on thin strokes or small interior detail.
The source must contain no text, logos, UI panels, copied characters, signatures, watermarks, cast shadows, detached particles, or scenery.

## Target Mapping

The app target receives:

- `sprite-hero-idle`;
- `sprite-hero-breathe-in`;
- `sprite-hero-breathe-out`;
- `icon-battle-flag`;
- `icon-victory-trophy`;
- `icon-add`;
- `icon-notifications-disabled`;
- `icon-retry`;
- `icon-complete`;
- `icon-delete`.

The widget target receives:

- `icon-complete`;
- `icon-stale-warning`;
- `icon-protection-shield`.

The same approved `icon-complete` pixels are copied into both asset catalogs because the app and extension compile separate catalogs.
No runtime file sharing or bundle lookup abstraction is introduced.

## Image Generation And Review Gate

Use the built-in `imagegen` path with the existing approved hero image as an identity reference.
Generate one four-by-three sheet on a perfectly flat magenta chroma-key background selected to avoid the subject palette.
Prefer `#FF00FF`, while allowing the extraction step to sample the actual border color if the generator shifts it slightly.

The workflow is binding:

1. generate one unsplit source sheet;
2. inspect the complete sheet for all twelve subjects, hero identity, pose continuity, icon readability, cell separation, unwanted text, and copied visual expression;
3. present the unsplit sheet to the user;
4. wait for explicit approval;
5. if rejected, make one targeted image edit or regeneration and repeat the review gate;
6. only after approval, copy the approved source into the workspace, remove the chroma key, and split the cells;
7. validate transparency, edge quality, cell bounds, center alignment, and nearest-neighbor scaling;
8. add only the approved final assets to the two asset catalogs.

No cropping, chroma-key removal, per-cell export, asset-catalog integration, or Swift implementation may occur before the user approves the unsplit source sheet.
Extraction must use rounded cumulative cell boundaries when generated dimensions do not divide evenly.
Opaque subject pixels must not be resampled.

## SwiftUI Integration

Extend `DungeonArtwork` with the two additional hero frames and the seven app icon cases.
Keep `DungeonArtworkView` as the app's fixed-frame, nearest-neighbor rendering seam.
Do not introduce a second app-side image wrapper.

Add a small widget-local artwork enum and fixed-frame decorative image view for the three widget assets.
This keeps widget bundle lookup explicit and avoids moving the existing app-only `DungeonArtwork` abstraction into shared code.

Replace the current symbols at these presentation seams:

```plaintext
HeroHeader
  -> battle flag
  -> victory trophy

HomeDungeonBoardView
  -> add marker
  -> empty-state battle flag
  -> notifications-disabled marker

QuestListSections
  -> completion marker
  -> delete marker

QuestRow and QuestResolutionView
  -> retry marker

WidgetDungeonView
  -> stale-warning or protection-shield marker
  -> completion marker
```

Use `Label`'s custom title and icon closures where text and an image form one control.
Render images as decorative whenever adjacent text or an explicit accessibility label already communicates the meaning.
Do not allow the image filename to become accessibility output.

## Hero Breathing Sequence

The visible breathing cycle is:

```plaintext
idle -> breathe in -> breathe out -> breathe in -> idle
```

The implementation may represent the repeated inhale as a four-step index sequence over three unique images.
Keep the index in `HeroSprite` as transient view state and advance it from a cancellable Swift concurrency task.
Use one slow fixed interval in the approximate range of `0.6` to `0.8` seconds per step so the loop reads as breathing rather than vibration.

The task runs only when the hero is idle and Reduce Motion is disabled.
It must stop when the view disappears, the hero enters mourning, or Reduce Motion becomes enabled.
Changing the frame must not apply implicit scale, offset, opacity, or cross-fade animation.
The existing mourning scale, rotation, offset, and accessibility label remain unchanged unless a direct conflict is found during implementation.

Do not persist the frame index or add it to `HeroState`, `Quest`, SwiftData, widget payloads, or app-wide state.

## Accessibility And Layout

Preserve the current combined labels such as `전투 N`, `승리 N`, `완료`, `삭제`, and `내일 도전하기`.
Preserve `용사` and `쓰러진 용사` as the hero's accessibility states regardless of the breathing frame.

The asset frame must remain stable while the image changes.
The HUD must not change height or horizontal spacing across frames.
Action rails, toolbar buttons, widget completion buttons, and form rows must retain their existing hit areas and text labels.

Verify the app in light and dark mode and with a large Korean accessibility text size.
Verify VoiceOver does not announce asset filenames or duplicate adjacent labels.
Verify Reduce Motion produces a static idle hero while other state meaning remains visible.

## Failure Handling

Reject the sheet before extraction if the hero changes identity, any icon is ambiguous at target size, a subject crosses a cell boundary, or the sheet contains text, signatures, merged cells, or copied expression.
Prefer a targeted image edit for one defective cell instead of regenerating an already coherent sheet.

If chroma removal leaves a visible fringe, retry local removal with a one-pixel edge contraction before considering regeneration.
If a generated dimension does not divide evenly, use rounded cumulative boundaries without resizing the source.
If an icon becomes unreadable at its actual render size, simplify its silhouette before increasing the existing UI frame.
Do not enlarge a control or row merely to accommodate decorative detail.

A missing or misspelled asset would render blank, so asset-name tests, asset-catalog compilation, and visual inspection are required before completion.

## Verification

Automated verification:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n 'Image\(systemName:|Label\([^\n]*systemImage:' QuestKeeper QuestKeeperWidget
```

Focused automated coverage should protect:

- uniqueness of app artwork names;
- the three unique idle animation frames;
- the ordered breathing sequence;
- the static-frame decision for mourning and Reduce Motion;
- widget artwork-name uniqueness.

Manual simulator verification:

- observe the hero for multiple breathing cycles and confirm that the feet, center, and HUD layout do not jitter;
- enable Reduce Motion and confirm the hero remains on the stable idle frame;
- toggle mourning state and confirm the existing mourning presentation and label remain intact;
- inspect the HUD battle and victory counts in compact and accessibility layouts;
- inspect empty dungeon, add controls, disabled-notification guidance, retry actions, completion and delete rails;
- inspect small and medium widgets in current, stale, empty, and active-mob states;
- confirm all icons remain crisp and readable in light and dark mode;
- confirm VoiceOver reads the existing Korean meaning once and never reads an asset filename.

## Acceptance Criteria

- The user approved the unsplit twelve-cell source sheet before extraction.
- Every current SF Symbol under the app and widget source directories is replaced by an approved pixel asset.
- The app HUD hero uses three unique approved frames in a stable breathing loop.
- Reduce Motion and mourning display a stable frame without a repeating loop.
- App and widget asset catalogs contain only the assets required by their target.
- Existing labels, actions, hit areas, row heights, navigation, and widget intent behavior remain unchanged.
- `Quest` and other persisted or derived domain models remain unchanged.
- Generated artwork is original and does not copy the reference application's protected expression.
- No third-party dependency is added.
- `QuestKeeperTests` pass and both app and widget schemes build on the selected simulator.
- Required visual and accessibility states are manually observed in the iOS Simulator.
