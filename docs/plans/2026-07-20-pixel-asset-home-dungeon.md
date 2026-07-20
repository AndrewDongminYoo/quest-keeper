# Pixel Asset Home Dungeon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home dungeon's code-drawn hero and monster placeholders plus selected SF Symbols with an original, user-approved pixel-art asset set generated through `imagegen`.

**Architecture:** Generate one 4-by-2 source sprite sheet and stop for user approval before any extraction. After approval, remove the chroma key, split the sheet into eight app assets, map derived UI state to asset names through a pure `DungeonArtwork` enum, and render those assets through a small SwiftUI view while leaving SwiftData, notification, widget, and battle-state ownership unchanged.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Xcode asset catalogs, built-in `imagegen`, bundled chroma-key removal helper, ImageMagick already installed at `/opt/homebrew/bin/magick`, iOS Simulator.

## Global Constraints

- Follow `BLUEPRINT.md` for product and persistence rules and `DESIGN.md` for visual direction.
- Treat https://itleader.tistory.com/m/5 as interaction and mood reference only; do not copy its layout, characters, sprites, colors, or branding.
- Do not crop, remove the chroma key, split, copy into the workspace, or integrate the generated sheet until the user explicitly approves the unsplit image.
- Keep `Quest` raw-facts-only; do not persist asset names, monster types, mob levels, hero state, battle phases, or animation state.
- Keep the current quest-row minimum height of `92` points and current `20`-point hero and `30`-point monster frames unless manual QA proves a small frame adjustment is necessary.
- Preserve Dynamic Type, VoiceOver semantics, Reduce Motion, light mode, dark mode, notifications, widget snapshots, and existing quest actions.
- Do not add dependencies, SpriteKit, SceneKit, a bitmap font, categories, inventory, persistent character levels, or a completed-log screen.
- Use Korean for existing user-facing copy and English for code identifiers and commit messages.
- Keep the widget's shared code-drawn `PixelSprite` path unchanged; AND-42 covers the app home dungeon only.

---

## File Map

- Create `docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png`: approved unsplit source image copied from the built-in generation output after approval.
- Create `docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png`: approved sheet after chroma-key removal.
- Create `docs/notes/010-pixel-asset-generation.md`: final prompt, review decision, cell order, asset inventory, and processing commands.
- Create eight `QuestKeeper/Assets.xcassets/sprite-*.imageset/` directories containing one PNG and one `Contents.json` each.
- Create `QuestKeeper/Views/DungeonArtwork.swift`: pure derived-state-to-asset mapping and reusable asset-backed SwiftUI sprite view.
- Modify `QuestKeeper/Views/HeroSprite.swift`: choose idle or mourning hero artwork and suppress motion when requested.
- Modify `QuestKeeper/Views/QuestRow.swift`: render approved mob, grave, reward, and impact artwork without changing row state ownership or height.
- Create `QuestKeeperTests/DungeonArtworkTests.swift`: protect mob-tier mapping and asset-name uniqueness.
- Preserve `QuestKeeperShared/PixelSprite.swift`: it remains the widget rendering path and is not edited.

---

### Task 1: Generate The Unsplit Sprite Sheet And Stop For Approval

**Files:**

- No workspace file is created or modified before approval.
- Generated preview remains under the built-in tool's `$CODEX_HOME/generated_images/` location until approval.

**Interfaces:**

- Consumes: approved Spec 010 and the palette semantics in `DESIGN.md`.
- Produces: one user-reviewed 4-by-2 source sheet with the exact row-major cell order specified below.

- [ ] **Step 1: Confirm the worktree baseline**

Run:

```bash
git status --short
git log -1 --oneline
```

Expected: only the approved spec-status and implementation-plan documentation changes are present; no implementation assets or Swift files have changed.

- [ ] **Step 2: Generate one unsplit sheet with the built-in `imagegen` tool**

Use this exact prompt:

```plaintext
Create an original pixel-art sprite sheet for a Korean iOS productivity game called QuestKeeper. This is a new design, not a recreation of any existing app or game. Use a strict 4-column by 2-row grid with eight equally sized cells, generous empty margins inside every cell, consistent front-facing three-quarter dungeon-game perspective, consistent pixel scale, crisp hard pixel edges, no antialiasing, and a restrained 16-bit dungeon-at-night palette. Use dark charcoal outlines, slate stone neutrals, muted blue for the hero, warm gold for victory, restrained red-orange only for danger, and teal only as a small guide accent. The perfectly flat background of the entire image must be solid chroma magenta #FF00FF with no texture, shading, shadow, border, grid line, or gradient.

Exact row-major cell order:
1. small friendly adventurer hero standing idle, readable at tiny HUD size;
2. the same hero in a temporary mourning or knocked-down pose, gentle rather than gruesome;
3. small low-threat slime monster;
4. medium-threat skeleton monster;
5. high-threat compact dragon monster;
6. temporary daily-grave marker shaped around the established (+) motif, no number and no permanent memorial feeling;
7. compact gold coin or star victory reward;
8. compact one-hit battle impact burst.

Every subject must be isolated and fully contained inside its own cell. Keep silhouettes distinct at 20 to 30 point display sizes. No text, letters, numbers, logos, UI panels, buttons, scenery, character names, signatures, watermarks, extra objects, repeated subjects, gore, gradients, soft painting, 3D rendering, or reference-app imitation.
```

Expected: one image containing all eight requested subjects with no text or UI chrome.

- [ ] **Step 3: Inspect the generated image without editing it**

Use `view_image` on the generated file at original detail.

Check all of the following:

- cell order is exactly hero idle, hero mourning, slime, skeleton, dragon, daily grave, victory reward, battle impact;
- all subjects are fully separated by magenta space;
- hero states clearly belong to the same character;
- monster silhouettes remain distinct when mentally reduced to `30` points;
- no text, logo, signature, watermark, extra subject, or copied reference expression appears;
- the background is visually flat `#FF00FF` with no shadows or grid lines.

- [ ] **Step 4: Present the unsplit sheet and stop the execution turn**

Before the image tool call, tell the user that this is the mandatory unsplit review and ask them to reply with approval or one targeted revision request.
After the image is generated, output nothing else because the built-in image tool requires the generated image to be the final item in that turn.

Expected: execution pauses with no workspace image, crop, transparent conversion, asset catalog change, Swift edit, or commit.

---

### Task 2: Preserve And Extract The Approved Artwork

**Files:**

- Create: `docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png`
- Create: `docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png`
- Create: `docs/notes/010-pixel-asset-generation.md`
- Create: `QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/sprite-hero-idle.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-hero-mourning.imageset/sprite-hero-mourning.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-slime.imageset/sprite-slime.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-skeleton.imageset/sprite-skeleton.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-dragon.imageset/sprite-dragon.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-daily-grave.imageset/sprite-daily-grave.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-victory-reward.imageset/sprite-victory-reward.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-battle-impact.imageset/sprite-battle-impact.png`
- Create: one `Contents.json` beside each PNG above.

**Interfaces:**

- Consumes: the exact source file explicitly approved in Task 1.
- Produces: eight transparent app assets named `sprite-hero-idle`, `sprite-hero-mourning`, `sprite-slime`, `sprite-skeleton`, `sprite-dragon`, `sprite-daily-grave`, `sprite-victory-reward`, and `sprite-battle-impact`.

- [ ] **Step 1: Copy only the approved source into the workspace**

Resolve the newest built-in PNG after confirming no later image generation occurred after the approved Task 1 result:

```bash
approved_generated_file=$(
  find "${CODEX_HOME:-$HOME/.codex}/generated_images" -type f -name '*.png' -print0 \
    | xargs -0 stat -f '%m %N' \
    | sort -rn \
    | sed -n '1s/^[0-9]* //p'
)
test -n "$approved_generated_file"
mkdir -p docs/assets/pixel-home-dungeon
cp "$approved_generated_file" docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png
```

Expected: the SHA-256 digest of the workspace copy matches the approved generated file.

Verify:

```bash
shasum -a 256 "$approved_generated_file" docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png
```

- [ ] **Step 2: Remove chroma magenta with the bundled helper**

Run:

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png \
  --out docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

Expected: output is a PNG with an alpha channel and transparent corners.

Verify:

```bash
/opt/homebrew/bin/magick identify -format '%m %[channels] %wx%h\n' docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png
```

Expected: format `PNG`, channels include alpha, and dimensions match the approved source.

- [ ] **Step 3: Split the transparent sheet into the fixed 4-by-2 grid**

Run:

```bash
asset_work_dir=$(mktemp -d /tmp/questkeeper-pixel-assets.XXXXXX)
/opt/homebrew/bin/magick docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png \
  -crop 4x2@ +repage +adjoin "$asset_work_dir/cell-%d.png"
find "$asset_work_dir" -name 'cell-*.png' -type f | sort
```

Expected: exactly `cell-0.png` through `cell-7.png` in row-major order.

- [ ] **Step 4: Create image sets and copy the row-major cells**

Run:

```bash
for name in hero-idle hero-mourning slime skeleton dragon daily-grave victory-reward battle-impact; do
  mkdir -p "QuestKeeper/Assets.xcassets/sprite-$name.imageset"
done
cp "$asset_work_dir/cell-0.png" QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/sprite-hero-idle.png
cp "$asset_work_dir/cell-1.png" QuestKeeper/Assets.xcassets/sprite-hero-mourning.imageset/sprite-hero-mourning.png
cp "$asset_work_dir/cell-2.png" QuestKeeper/Assets.xcassets/sprite-slime.imageset/sprite-slime.png
cp "$asset_work_dir/cell-3.png" QuestKeeper/Assets.xcassets/sprite-skeleton.imageset/sprite-skeleton.png
cp "$asset_work_dir/cell-4.png" QuestKeeper/Assets.xcassets/sprite-dragon.imageset/sprite-dragon.png
cp "$asset_work_dir/cell-5.png" QuestKeeper/Assets.xcassets/sprite-daily-grave.imageset/sprite-daily-grave.png
cp "$asset_work_dir/cell-6.png" QuestKeeper/Assets.xcassets/sprite-victory-reward.imageset/sprite-victory-reward.png
cp "$asset_work_dir/cell-7.png" QuestKeeper/Assets.xcassets/sprite-battle-impact.imageset/sprite-battle-impact.png
```

- [ ] **Step 5: Add the exact `Contents.json` contract to every image set**

Use `apply_patch` to add one `Contents.json` per image set.
Each file follows this exact contract, with `filename` set to the PNG already named in that directory:

```json
{
  "images" : [
    {
      "filename" : "sprite-hero-idle.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Expected: each imageset has one PNG and one valid `Contents.json`; no generated cell is referenced twice.

- [ ] **Step 6: Record provenance and processing without copying article content**

Create `docs/notes/010-pixel-asset-generation.md` with the approved prompt and fixed asset inventory:

```markdown
# Pixel Asset Generation Record

## Source

- Tool: built-in `imagegen`
- Review: approved before extraction
- Reference use: interaction and retro-game mood only

## Final Prompt

```plaintext
Create an original pixel-art sprite sheet for a Korean iOS productivity game called QuestKeeper. This is a new design, not a recreation of any existing app or game. Use a strict 4-column by 2-row grid with eight equally sized cells, generous empty margins inside every cell, consistent front-facing three-quarter dungeon-game perspective, consistent pixel scale, crisp hard pixel edges, no antialiasing, and a restrained 16-bit dungeon-at-night palette. Use dark charcoal outlines, slate stone neutrals, muted blue for the hero, warm gold for victory, restrained red-orange only for danger, and teal only as a small guide accent. The perfectly flat background of the entire image must be solid chroma magenta #FF00FF with no texture, shading, shadow, border, grid line, or gradient.

Exact row-major cell order:
1. small friendly adventurer hero standing idle, readable at tiny HUD size;
2. the same hero in a temporary mourning or knocked-down pose, gentle rather than gruesome;
3. small low-threat slime monster;
4. medium-threat skeleton monster;
5. high-threat compact dragon monster;
6. temporary daily-grave marker shaped around the established (+) motif, no number and no permanent memorial feeling;
7. compact gold coin or star victory reward;
8. compact one-hit battle impact burst.

Every subject must be isolated and fully contained inside its own cell. Keep silhouettes distinct at 20 to 30 point display sizes. No text, letters, numbers, logos, UI panels, buttons, scenery, character names, signatures, watermarks, extra objects, repeated subjects, gore, gradients, soft painting, 3D rendering, or reference-app imitation.
```

## Cell Order

1. `sprite-hero-idle`
2. `sprite-hero-mourning`
3. `sprite-slime`
4. `sprite-skeleton`
5. `sprite-dragon`
6. `sprite-daily-grave`
7. `sprite-victory-reward`
8. `sprite-battle-impact`

## Processing

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet.png \
  --out docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
/opt/homebrew/bin/magick docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png \
  -crop 4x2@ +repage +adjoin "$asset_work_dir/cell-%d.png"
```
```

- [ ] **Step 7: Inspect every extracted image before committing**

Use `view_image` at original detail for all eight PNGs.
Reject extraction if any subject is clipped, shares pixels with a neighbor, retains a magenta fringe, or is mapped to the wrong filename.
If only a thin fringe exists, rerun the chroma helper once with `--edge-contract 1` and repeat the split.

- [ ] **Step 8: Validate and commit the approved asset unit**

Run:

```bash
find QuestKeeper/Assets.xcassets -path '*/sprite-*.imageset/*' -type f | sort
/opt/homebrew/bin/magick identify -format '%f %m %[channels] %wx%h\n' QuestKeeper/Assets.xcassets/sprite-*.imageset/*.png
git diff --check
git add docs/assets/pixel-home-dungeon docs/notes/010-pixel-asset-generation.md QuestKeeper/Assets.xcassets/sprite-*.imageset
git diff --cached --check
git diff --cached --stat
git commit -m 'feat(assets): add approved pixel dungeon artwork'
```

Expected: eight transparent PNG assets, the approved source files, and one provenance note are committed together.

---

### Task 3: Add A Pure Artwork Mapping Seam

**Files:**

- Create: `QuestKeeper/Views/DungeonArtwork.swift`
- Create: `QuestKeeperTests/DungeonArtworkTests.swift`

**Interfaces:**

- Consumes: the eight asset names created in Task 2.
- Produces: `nonisolated enum DungeonArtwork: String, CaseIterable, Sendable`, `DungeonArtwork.monster(level:) -> DungeonArtwork`, and `DungeonArtworkView`.

- [ ] **Step 1: Write the failing mapping tests**

Create `QuestKeeperTests/DungeonArtworkTests.swift`:

```swift
import Testing
@testable import QuestKeeper

struct DungeonArtworkTests {
    @Test("mob levels map to the three visual tiers")
    func monsterTierMapping() {
        #expect(DungeonArtwork.monster(level: 0) == .slime)
        #expect(DungeonArtwork.monster(level: 1) == .slime)
        #expect(DungeonArtwork.monster(level: 2) == .skeleton)
        #expect(DungeonArtwork.monster(level: 3) == .skeleton)
        #expect(DungeonArtwork.monster(level: 4) == .dragon)
        #expect(DungeonArtwork.monster(level: 5) == .dragon)
    }

    @Test("every artwork case has a unique asset name")
    func assetNamesAreUnique() {
        let names = DungeonArtwork.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }
}
```

- [ ] **Step 2: Run the focused test and confirm it fails for the missing type**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonArtworkTests
```

Expected: FAIL because `DungeonArtwork` does not exist.

- [ ] **Step 3: Add the minimal mapping and rendering seam**

Create `QuestKeeper/Views/DungeonArtwork.swift`:

```swift
import SwiftUI

nonisolated enum DungeonArtwork: String, CaseIterable, Sendable {
    case heroIdle = "sprite-hero-idle"
    case heroMourning = "sprite-hero-mourning"
    case slime = "sprite-slime"
    case skeleton = "sprite-skeleton"
    case dragon = "sprite-dragon"
    case dailyGrave = "sprite-daily-grave"
    case victoryReward = "sprite-victory-reward"
    case battleImpact = "sprite-battle-impact"

    static func monster(level: Int) -> DungeonArtwork {
        switch level {
        case ..<2: .slime
        case 2..<4: .skeleton
        default: .dragon
        }
    }
}

struct DungeonArtworkView: View {
    let artwork: DungeonArtwork
    let size: CGFloat

    var body: some View {
        Image(artwork.rawValue)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 4: Run the focused tests and confirm they pass**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonArtworkTests
```

Expected: PASS with both `DungeonArtworkTests` tests successful.

---

### Task 4: Render Approved Artwork In The Home Dungeon

**Files:**

- Modify: `QuestKeeper/Views/HeroSprite.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`
- Test: `QuestKeeperTests/DungeonArtworkTests.swift`

**Interfaces:**

- Consumes: `DungeonArtwork`, `DungeonArtwork.monster(level:)`, and `DungeonArtworkView` from Task 3.
- Produces: asset-backed hero, monster, daily-grave, victory-reward, and battle-impact presentations while preserving existing callbacks and row-local `QuestBattlePhase`.

- [ ] **Step 1: Replace the hero bitmap while preserving its public interface**

Change `HeroSprite.body` to:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

var body: some View {
    DungeonArtworkView(
        artwork: isMourning ? .heroMourning : .heroIdle,
        size: size
    )
    .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isMourning)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(isMourning ? "쓰러진 용사" : "용사")
}
```

Remove the obsolete `PixelSprite`, palette, and rotation code from `HeroSprite` only.
Do not edit `QuestKeeperShared/PixelSprite.swift` because the widget still consumes it.

- [ ] **Step 2: Replace the monster glyph and suppress impact motion for Reduce Motion**

Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to `MonsterGlyph` and replace its body with:

```swift
var body: some View {
    ZStack {
        if battlePhase == .striking {
            DungeonArtworkView(artwork: .battleImpact, size: 34)
                .transition(.opacity)
        }
        DungeonArtworkView(artwork: .monster(level: level), size: 30)
    }
    .frame(width: 34, height: 34)
    .scaleEffect(reduceMotion ? 1 : battlePhase == .striking ? 1.22 : battlePhase == .defeated ? 0.82 : 1)
    .rotationEffect(.degrees(reduceMotion ? 0 : battlePhase == .striking ? -8 : battlePhase == .defeated ? 10 : 0))
    .opacity(battlePhase == .defeated ? 0.35 : 1)
    .transaction { transaction in
        if reduceMotion {
            transaction.animation = nil
        }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("몹 레벨 \(level)")
}
```

Expected: the derived integer level still selects the visual tier at render time; no monster type is stored.

- [ ] **Step 3: Replace the daily-grave SF Symbol without changing row actions**

In `DailyGraveRow`, replace the leading `Image(systemName:)` block with:

```swift
DungeonArtworkView(artwork: .dailyGrave, size: 34)
    .accessibilityHidden(true)
```

Remove `icon` and `iconTint` from `DailyGraveRow.Style` and their values from `.mourning` and `.rest`.
Keep captions, caption tints, backgrounds, borders, accessibility values, and the `내일 도전하기` button unchanged.

- [ ] **Step 4: Add the compact reward image without changing badge height**

Replace the defeated-phase `Text("VICTORY +1")` with:

```swift
HStack(spacing: 4) {
    DungeonArtworkView(artwork: .victoryReward, size: 14)
    Text("VICTORY +1")
}
.font(.caption2.monospaced().weight(.black))
.foregroundStyle(DungeonPalette.victory)
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 2))
.transition(.scale.combined(with: .opacity))
```

Expected: text remains the non-color cue and the containing row still has `minHeight: 92`.

- [ ] **Step 5: Run the focused mapping tests and build immediately**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonArtworkTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: both commands exit `0` with no Swift compiler errors or missing asset warnings.

- [ ] **Step 6: Commit the mapping and home-dungeon integration together**

Run:

```bash
git add QuestKeeper/Views/DungeonArtwork.swift QuestKeeper/Views/HeroSprite.swift QuestKeeper/Views/QuestRow.swift QuestKeeperTests/DungeonArtworkTests.swift
git diff --cached --check
git diff --cached --stat
git commit -m 'feat(ui): render pixel artwork in home dungeon'
```

Expected: one atomic commit containing the pure mapping, its tests, and all app consumers.

---

### Task 5: Verify The Full Behavior And Manually QA The App

**Files:**

- Verify: all files changed in Tasks 2 through 4.
- Do not create snapshot baselines or unrelated UI-test files.

**Interfaces:**

- Consumes: completed asset and UI commits.
- Produces: concrete build, unit-test, raw-facts, accessibility, and simulator evidence for AND-42.

- [ ] **Step 1: Run the full scoped unit-test target**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Expected: exit `0` and `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run the app build and source guards**

Run:

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n '^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:private|fileprivate|internal|public|package|open)?\s*(?:var|let)\s+(?:[Hh][Pp]|isDead|graveCount|retryCount|notificationID|isNotificationScheduled|widgetID|mobLevel|monsterType|urgency)\b' QuestKeeper/Models
```

Expected: build exits `0`, diff check emits no output, and the raw-facts guard finds no forbidden stored fields.

- [ ] **Step 3: Launch the app in the iPhone 17e Simulator**

Use the iOS debugger workflow to boot at most one simulator, install the just-built app, and launch `QuestKeeper`.
Do not run another heavy mobile job concurrently.

Expected: the app opens to `HomeDungeonBoardView` without a crash or missing-image placeholder.

- [ ] **Step 4: Observe all required visual states**

Use the simulator to verify:

- empty dungeon primary action is still clear;
- active quests expose slime, skeleton, and dragon tiers through test deadlines and importance values;
- hero idle and mourning assets are distinct;
- newly missed and older daily graves retain their captions and recovery action;
- completion shows battle impact, then reward plus `VICTORY +1`, without changing row height;
- repeated completion input remains blocked during resolution;
- edit, delete, and `내일 도전하기` still call their existing flows;
- light and dark mode retain readable text and distinct sprites;
- a multiline Korean title remains readable at a large accessibility text size;
- Reduce Motion removes scale and rotation impact while preserving opacity and text state;
- VoiceOver reads quest title, countdown, mob level, and actions without reading asset filenames.

Capture screenshots for empty, three mob tiers, victory, and daily-grave states as QA evidence, but do not commit temporary screenshots.

- [ ] **Step 5: Reconcile the plan and repository state**

Run:

```bash
git status --short
git log -3 --oneline
```

Expected: no uncommitted implementation files remain; recent history includes the asset and UI commits from Tasks 2 and 4 plus the plan/spec documentation state.

- [ ] **Step 6: Report completion evidence**

Report the generated asset paths, final prompt record, commits, exact test/build commands, simulator states observed, and any pre-existing failure left untouched.
Do not claim WidgetKit Home Screen rendering or notification delivery was verified unless those OS surfaces were separately observed.
