# Combat Asset Generation

The user approved the two source sheets on 2026-08-07.
The project keeps pixel-identical, losslessly optimized copies so the runtime catalog can be regenerated without relying on a Codex-local path.

## Approved sources

- Hero source: `docs/assets/pixel-combat-customization/questkeeper-heroes-source.png`
  - Built-in mode: image editing with the approved QuestKeeper hero as the identity reference
  - Generated filename: `questkeeper-heroes-10-flat.png`
  - Dimensions: 1774 × 887 pixels
  - Original SHA-256: `7fd61b3cf7411aa50f1463e1c2185e506c67a536c358a0a8838b65ee8ee76944`
  - Repository SHA-256 after the PNG quality hook: `3a191d94842662fd729dfc75ab74e6cb85d89f6d77f250225627fc37a20ccce5`
- Left-facing monster source: `docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png`
  - Built-in mode: image generation with the approved QuestKeeper dungeon sheet as the style and identity reference
  - Generated filename: `questkeeper-monsters-9-left-flat-v2.png`
  - Dimensions: 1254 × 1254 pixels
  - Original SHA-256: `53fd779a9d56800d1b74517684f03a09ec095344ce3c57a7a27c8d18c9b0979a`
  - Repository SHA-256 after the PNG quality hook: `4d25b875f0c6801d13483e3c06432404aa13d67567cb261202212731e2f702d5`

ImageMagick `compare -metric AE` reports zero changed pixels for each source pair.
The generated files originally lived in the built-in tool's local cache; this public record keeps the stable filenames and hashes while omitting the machine-specific absolute cache prefix and session identifier.

## Final prompts and cell order

The final monster prompt requested the current QuestKeeper dungeon style and identities in this strict three-by-three row-major grid:

```plaintext
slime, bat, mushroom
skeleton, orc, mimic
dragon, golem, lich
```

It required one centered subject per equal cell, left-facing or left-biased three-quarter poses, a flat `#FF00FF` background, uniform safe margins, the existing outline weight and palette, and no grid lines, text, scenery, particles, shadows, gradients, signatures, or cell crossings.
The first monster result was revised specifically to make the full lineup face toward the right-facing hero; the user approved the resulting `v2` sheet.

The final hero prompt used the current QuestKeeper hero as the identity reference and requested this strict five-column-by-two-row grid:

```plaintext
male idle, male breathe-in, male breathe-out, male wind-up, male strike
female idle, female breathe-in, female breathe-out, female wind-up, female strike
```

It required anchored feet and horizontal centers, the same blue hair palette in all ten cells, consistent armor and sword, readable poses at 36 points, a flat `#FF00FF` background, and no grid lines, text, extra objects, shadows, gradients, signatures, or cell crossings.
The user approved the final hero sheet before extraction; the later targeted revision applied to monster direction.

## Extraction decisions

Monster boundaries use rounded cumulative thirds on both axes with 12-pixel safe insets; the middle row uses a 40-pixel bottom inset and the golem cell uses a 40-pixel right inset to exclude neighboring chroma artifacts.
Hero boundaries use rounded cumulative fifths horizontally and halves vertically with 12-pixel insets on every edge.
Every hero subject is centered horizontally without resizing opaque pixels and anchored to the same 384-pixel baseline on a transparent 512 × 512 canvas.

The source backgrounds are the approved flat `#FF00FF` chroma key.
The processing script removes that key with ImageMagick, crops rounded cumulative grid boundaries with safe cell insets, and places every frame on a transparent 512 × 512 canvas without resizing its opaque pixels.
The source cobalt hair palette is selected around `#0346AA` at 12% fuzz; black, brown, and red variants preserve the source shading through color matrices while the blue variant remains byte-equivalent to the cropped source pixels.
No horizontal mirroring is performed: heroes retain their approved right-facing pose and monsters retain their approved left-facing pose.

## Reproduction

```bash
/bin/bash scripts/process-combat-assets.sh \
  docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png \
  docs/assets/pixel-combat-customization/questkeeper-heroes-source.png \
  .
/bin/bash scripts/test-combat-assets.sh .
```
