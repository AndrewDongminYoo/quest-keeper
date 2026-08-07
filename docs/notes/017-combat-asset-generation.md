# Combat Asset Generation

The user approved the two source sheets on 2026-08-07.
The project keeps pixel-identical, losslessly optimized copies so the runtime catalog can be regenerated without relying on a Codex-local path.

## Approved sources

- Hero source: `docs/assets/pixel-combat-customization/questkeeper-heroes-source.png`
  - Built-in image generation output: `/Users/dongminyu/.codex/generated_images/019fda45-a891-7d50-9012-6c1a7684c1cb/questkeeper-heroes-10-flat.png`
  - Original SHA-256: `7fd61b3cf7411aa50f1463e1c2185e506c67a536c358a0a8838b65ee8ee76944`
  - Repository SHA-256 after the PNG quality hook: `3a191d94842662fd729dfc75ab74e6cb85d89f6d77f250225627fc37a20ccce5`
- Left-facing monster source: `docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png`
  - Built-in image generation output: `/Users/dongminyu/.codex/generated_images/019fda45-a891-7d50-9012-6c1a7684c1cb/questkeeper-monsters-9-left-flat-v2.png`
  - Original SHA-256: `53fd779a9d56800d1b74517684f03a09ec095344ce3c57a7a27c8d18c9b0979a`
  - Repository SHA-256 after the PNG quality hook: `4d25b875f0c6801d13483e3c06432404aa13d67567cb261202212731e2f702d5`

ImageMagick `compare -metric AE` reports zero changed pixels for each source pair.

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
