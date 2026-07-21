# Pixel UI Asset Generation Record

## Source

- Tool: built-in `imagegen`
- Mode: identity-preserving edit from the approved QuestKeeper hero asset
- Review: revised unsplit sheet approved before extraction on 2026-07-21
- Source dimensions: `1448×1086`
- Cell dimensions: `362×362`
- Source SHA-256: `6aff0f9a561f576768d03ded5ae70df5ab6bfb7efba5cd03a9fa94dae8acb83f`
- Reference use: the existing QuestKeeper hero asset was the identity reference; no external application artwork was supplied to the generator

## Initial Prompt

```plaintext
Use case: precise-object-edit
Asset type: original pixel-art sprite sheet for QuestKeeper iOS app and widget
Input image: the supplied approved QuestKeeper hero is the identity reference and edit target for the first three cells

Create one original pixel-art sprite sheet for a Korean iOS productivity game called QuestKeeper. Preserve the supplied hero's exact identity, clothing, blue hair, body proportions, muted blue and slate palette, charcoal outline weight, front-facing three-quarter viewing angle, foot position, sword, and horizontal center. This is a new original UI asset set and must not recreate any existing app or game.

Use a strict 4-column by 3-row grid with exactly twelve equal cells in row-major order. Place exactly one subject centered in every cell. Keep every opaque silhouette fully inside its cell with a generous uniform safe margin. Use the same crisp hard-edged pixel scale across all cells, no antialiasing, no gradients, no soft painting, and no 3D rendering. The entire background must be perfectly flat solid chroma magenta #FF00FF with no grid lines, borders, texture, lighting variation, floor plane, shadow, glow, halo, or detached particles. Do not use #FF00FF or near-magenta pixels inside any subject.

Exact row-major cell order:
1. the supplied hero in the neutral approved idle pose;
2. the exact same hero at a very subtle inhale pose, with feet and horizontal center unchanged;
3. the exact same hero at a very subtle exhale pose, with feet and horizontal center unchanged;
4. compact battle flag icon;
5. compact victory trophy icon;
6. compact add marker icon;
7. compact notifications-disabled bell icon;
8. compact retry marker icon;
9. compact completion check icon;
10. compact delete marker icon;
11. compact stale-warning marker icon;
12. compact protection shield icon.

The three hero cells must depict exactly the same character and differ only by one or two pixels of torso, shoulder, cape, or clothing movement that reads as gentle breathing. Do not move the feet, change equipment, alter facial identity, change canvas scale, or remove the sword. Design every icon for recognition at 12 to 20 points using chunky silhouettes, dark charcoal outlines, slate stone neutrals, muted blue, warm gold for victory, restrained red-orange for warning or deletion, and teal only as a small guide accent. Do not depend on thin strokes or tiny internal marks.

Constraints: exactly twelve subjects; one subject per cell; consistent safe margins; fully separated subjects; anchored hero feet; original QuestKeeper visual language; flat #FF00FF chroma background.
Avoid: text, letters, numbers, logos, UI panels, buttons, scenery, signatures, watermarks, repeated subjects, extra objects, gore, shadows, glow, gradients, merged cells, crossing cell boundaries, reference-app imitation.
```

## Revision Decision

The first unsplit sheet was rejected because the three hero poses were not distinguishable at review size.
The icon cells were accepted as a coherent direction, so the second pass used a targeted edit that strengthened only the inhale and exhale poses while asking the generator to preserve the remaining sheet.

## Approved Revision Prompt

```plaintext
Use case: precise-object-edit
Asset type: revised QuestKeeper pixel-art sprite sheet
Input image: edit target; preserve the complete 4-column by 3-row sheet structure

Primary request: Change only hero cells 2 and 3 so the breathing animation is unmistakably visible at a 20-point HUD size. Preserve hero cell 1 and every icon in cells 4 through 12 exactly in subject, meaning, order, palette, scale, and position. Preserve the flat solid magenta background, equal cell layout, safe margins, and crisp hard pixel edges.

Cell 2, inhale: keep the same hero identity, equipment, sword, feet, and horizontal center, but visibly raise the shoulders and upper torso by a chunky 3 to 5 output pixels, expand the chest and scarf upward, lift the sword hand slightly, and raise the hair silhouette slightly. The feet remain planted at exactly the same baseline. This must be clearly distinguishable from cell 1 when viewed as a small thumbnail.

Cell 3, exhale: keep the same hero identity, equipment, sword, feet, and horizontal center, but visibly lower the shoulders and upper torso by a chunky 3 to 5 output pixels, compress the chest, settle the scarf and cape downward, lower the sword hand slightly, and lower the hair silhouette slightly. The feet remain planted at exactly the same baseline. This must be clearly distinguishable from both cell 1 and cell 2 when viewed as a small thumbnail.

Motion rule: the sequence cell 1 neutral -> cell 2 inhale/up -> cell 3 exhale/down -> cell 2 inhale/up must show a gentle but obvious vertical breathing bob. It must not look like three duplicates. Use discrete pixel clusters rather than blur, scaling, antialiasing, crossfade, or changed character size.

Strict invariants: same face, hair, clothes, proportions, sword, palette, outline, viewing angle, feet baseline, horizontal center, and per-cell canvas alignment. Keep exactly twelve cells and one subject per cell. Keep all nine icons unchanged and in the same locations. Keep the background perfectly uniform #FF00FF. No text, grid lines, shadows, gradients, glow, extra objects, watermark, merged cells, or subject crossing a boundary.
```

## Cell Inventory

1. `sprite-hero-idle`
2. `sprite-hero-breathe-in`
3. `sprite-hero-breathe-out`
4. `icon-battle-flag`
5. `icon-victory-trophy`
6. `icon-add`
7. `icon-notifications-disabled`
8. `icon-retry`
9. `icon-complete`
10. `icon-delete`
11. `icon-stale-warning`
12. `icon-protection-shield`

## Processing

The approved source was copied without modification into the worktree's temporary processing directory.
The source border sampled as `#ED08EB`, so the installed chroma-key helper used border auto-detection, a soft matte, thresholds `12` and `220`, and despill.
The helper reported `1,150,488` fully transparent pixels and `16,433` partially transparent edge pixels out of `1,572,528` pixels.

The `1448×1086` source divides evenly into a four-column by three-row grid.
Initial extraction therefore used the exact x-boundaries `0, 362, 724, 1086, 1448` and y-boundaries `0, 362, 724, 1086` without resampling.
The icon cells remain on `362×362` transparent canvases.

## Victory Trophy Crop Correction

The first simulator review showed detached hero and flag pixels at the top of the second-row icons because the source artwork crossed the row boundary before exact grid extraction.
The corrected unsplit sheet was approved before re-extraction and is stored at `/Users/dongminyu/.codex/generated_images/019f7fc6-192b-76a2-ad97-41b557c30b75/exec-ffa12349-a7e8-4508-8468-7a45f8d2909b.png` with SHA-256 `8211ccef99f610e5dcd90d21160400c11b0830d4cc431da0e1fa758d0a7ff1c0`.
The second-row icons were re-extracted, and their top 64 pixels were fixed as transparent safe margins without moving or resampling the intended artwork.
The corrected SHA-256 values are `16c52c152c33d7fa360ba33d25b6e71483f215c3e871c566d516ae041fd06dc3` for `icon-victory-trophy.png`, `2de0d061e8becfe8983a9d025fd7f6390bee72f99f4cc3943fa053aa67795190` for `icon-add.png`, `d7ab457c8f85091629c210feda5eb32fc000cffa650c138a93cbc450e236279b` for `icon-notifications-disabled.png`, and `fc027adad220f694c3a89dfcae401ab6d5a5a47d4f4764c83f3b621121b890fd` for `icon-retry.png`.
Final runtime review also found isolated source-edge pixels beside the breathing-in hero and daily grave.
Their left 32 pixels were fixed as transparent safe margins without changing any decoded pixel outside that margin; the corrected SHA-256 values are `742097f5f199c017818bcad74f35e3aae5a7c47f8ba19946fad1903bafc9ff03` for `sprite-hero-breathe-in.png` and `62f9f1654f1f4703d0ad86382ca7f7b59e84f7293fabc51f72ef0f88a9862c5b` for `sprite-daily-grave.png`.

## Hero Frame Anchor Correction

Automated review later exposed that all three hero silhouettes crossed the first-row bottom boundary, so exact `362×362` cell extraction clipped feet and equipment and gave each animation frame a different horizontal center.
The hero-only correction returned to the approved original source with SHA-256 `6aff0f9a561f576768d03ded5ae70df5ab6bfb7efba5cd03a9fa94dae8acb83f`; the later trophy-correction sheet was not used for this repair because it had also removed the idle hero's sword.

Each hero was re-extracted from a `362×430` source region at x-offsets `0`, `362`, and `724` so pixels below the nominal row boundary remained available.
The inhale region's left 32 pixels were cleared again because they contain only the idle sword tip crossing the adjacent column.
After chroma removal, each complete silhouette was trimmed and placed without resampling on a shared `400×400` transparent canvas.
The placements are `+56+74` for idle, `+48+61` for inhale, and `+44+111` for exhale, producing a common horizontal center of `200`, an exclusive bottom baseline of `384`, and a 16-pixel bottom safe margin.

The corrected SHA-256 values are `3dae6d3d9aed6a8987b8c1e79592342e898d6d63bdf90412cfc6317f9b155726` for `sprite-hero-idle.png`, `a8a02d3ec292a62db5665a5c8228bc870225343ebfd17c9a12d5edca06098242` for `sprite-hero-breathe-in.png`, and `db721fdf505a48fd1b4cae6033c5d96342f5dee549ebfe02f69f62b6f7f862e8` for `sprite-hero-breathe-out.png`.
The daily-grave asset was inspected independently and left unchanged because both its decoded PNG and runtime rendering contain the complete gravestone.

## Battle Flag Bottom Correction

The battle flag also crossed the first-row bottom boundary, leaving its pole base cut off in the exact `362×362` cell extraction.
The complete `191×282` flag was recovered from a `362×430` region of the same approved original source and placed without resampling at `+75+64` on its existing `362×362` canvas.
This preserves the original horizontal position while adding the complete pole base and a 16-pixel bottom safe margin.
The corrected SHA-256 is `927d81bbd2270ebe243d12712888275b7302cae2ce9883828cb80f6bc9d832a2` for `icon-battle-flag.png`.

The app catalog receives the three hero frames and seven app icons.
The widget catalog receives completion, stale-warning, and protection-shield icons.
The same approved completion pixels are present in both target-specific catalogs.

Validation confirmed thirteen target PNG files, square `362×362` icon dimensions, shared `400×400` hero-frame dimensions, RGBA output, transparent pixels, nonempty subjects, valid JSON manifests, and visually correct cell mapping.
No subject redraw or opaque-pixel resampling was required.
