# Pixel Asset Generation Record

## Source

- Tool: built-in `imagegen`
- Review: approved before extraction on 2026-07-20
- Reference use: interaction and retro-game mood only
- Source SHA-256: `86841f47c1468f7283b911185e99f4e79f406a6f8f0982551bcecd449f1f7332`

## Final Prompt

```plaintext
Create an original pixel-art sprite sheet for a Korean iOS productivity game called QuestKeeper. This is a new design, not a recreation of any existing app or game. Use a 2:1 landscape canvas with a strict 4-column by 2-row grid so all eight cells are square. Cells 1–4 occupy the top row left-to-right; cells 5–8 occupy the bottom row left-to-right. Place exactly one subject in each cell, centered, with nothing crossing a cell boundary. Each subject's opaque silhouette should fill approximately 75–85% of its cell while retaining a uniform magenta safe margin. Design the hero specifically for a 20-point frame and monsters for 30-point frames using chunky, low-detail silhouettes. Do not rely on thin limbs, fine facial details, or tiny internal marks for recognition. Use a consistent front-facing three-quarter dungeon-game perspective, consistent pixel scale, crisp hard pixel edges, no antialiasing, and a restrained 16-bit dungeon-at-night palette. Use dark charcoal outlines, slate stone neutrals, muted blue for the hero, warm gold for victory, restrained red-orange only for danger, and teal only as a small guide accent. The perfectly flat background of the entire image must be solid chroma magenta #FF00FF with no texture, shading, shadow, border, grid line, or gradient. Do not use #FF00FF or near-magenta pixels anywhere inside a subject. No cast shadow, contact shadow, glow, halo, feathered edge, or detached particle may appear outside the main silhouette. Every subject edge must be opaque, crisp, and hard-edged.

Exact row-major cell order:
1. small friendly adventurer hero standing idle, readable at tiny HUD size;
2. the same hero in a temporary mourning or knocked-down pose, gentle rather than gruesome;
3. small low-threat slime monster;
4. medium-threat skeleton monster;
5. high-threat compact dragon monster;
6. temporary daily-grave marker shaped around the established (+) motif, no number and no permanent memorial feeling;
7. compact gold coin or star victory reward;
8. compact one-hit battle impact burst.

Cells 1 and 2 must depict exactly the same hero design: same clothing, hair, proportions, palette, and outline, changing only the pose. Cell 6 is a compact muted slate-gray temporary grave marker with one simple centered plus-shaped inset or cutout; it is not a medical symbol, number, counter, or permanent memorial. Every subject must be isolated and fully contained inside its own cell. Keep silhouettes distinct at 20 to 30 point display sizes. No text, letters, numbers, logos, UI panels, buttons, scenery, character names, signatures, watermarks, extra objects, repeated subjects, gore, gradients, soft painting, 3D rendering, or reference-app imitation.
```

## Cell Inventory

1. `sprite-hero-idle`
2. `sprite-hero-mourning`
3. `sprite-slime`
4. `sprite-skeleton`
5. `sprite-dragon`
6. `sprite-daily-grave`
7. `sprite-victory-reward`
8. `sprite-battle-impact`

## Processing

The approved 1774×887 source was copied without modification. The bundled chroma-key helper ran in an isolated `uv` environment with Pillow, sampled the border key as `#FA03F9`, and produced an RGBA PNG. Because the generated dimensions divide into 443.5-pixel cells, extraction used rounded cumulative boundaries without resampling: column widths `444, 443, 444, 443` and row heights `444, 443`. The dragon wing crossed five pixels into the next cell's empty margin, so its extraction includes that original strip and adds transparent padding; the grave extraction begins after the strip and is centered on a transparent square canvas. No opaque subject pixels were resampled or redrawn.
