# Pixel UI Icons And Hero Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every remaining app and widget SF Symbol with approved pixel artwork and add a stable three-frame breathing loop to the app HUD hero.

**Architecture:** Extend the existing app-side `DungeonArtwork` rendering seam for hero frames and app icons, while keeping a tiny widget-local artwork seam because the two targets compile separate asset catalogs. Keep breathing progress as cancellable view-local state in `HeroSprite`; domain models, derivation, persistence, and widget payloads remain unchanged.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Swift Testing, Xcode asset catalogs, built-in `imagegen`, local chroma-key removal, iOS Simulator `iPhone 17e`.

## Global Constraints

- The unsplit twelve-cell image must receive explicit user approval before cropping, chroma-key removal, asset-catalog integration, or Swift implementation.
- Use the existing approved hero image as the identity reference and preserve clothing, hair, proportions, palette, outline, viewing angle, feet position, and horizontal center.
- Generate exactly three hero frames and nine icons in a strict four-column by three-row grid.
- Replace every current `Image(systemName:)` and `Label(..., systemImage:)` under `QuestKeeper` and `QuestKeeperWidget`.
- Keep images decorative when adjacent text or an explicit accessibility label already communicates meaning.
- Keep all existing Korean labels, actions, button hit areas, row heights, navigation, and widget intent behavior.
- Reduce Motion and mourning use a stable frame with no repeating breathing task.
- Do not change `Quest`, SwiftData, derivation rules, notification behavior, or widget payloads.
- Do not add SpriteKit, SceneKit, a general animation framework, or a project dependency.
- Use nearest-neighbor rendering and fixed image frames.
- Preserve light mode, dark mode, Dynamic Type, VoiceOver, and widget rendering.

---

### Task 1: Generate And Approve The Unsplit Source Sheet

**Files:**

- Reference: `QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/sprite-hero-idle.png`
- Reference: `docs/specs/011-pixel-ui-icons-and-hero-animation.md`
- No repository files change before approval.

**Interfaces:**

- Consumes: the approved hero PNG and the twelve-cell inventory from Spec 011.
- Produces: one user-approved, unsplit four-column by three-row source sheet on a flat magenta background.

- [ ] **Step 1: Generate the unsplit sheet with the built-in image tool**

Use the `imagegen` skill and pass `QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/sprite-hero-idle.png` as the referenced image.
Use this exact prompt:

```plaintext
Create an original pixel-art sprite sheet for a Korean iOS productivity game called QuestKeeper. Edit from the supplied approved QuestKeeper hero reference: preserve that hero's exact identity, clothing, hair, body proportions, muted blue and slate palette, charcoal outline weight, front-facing three-quarter viewing angle, foot position, and horizontal center. This is a new original UI asset set and must not recreate any existing app or game.

Use a strict 4-column by 3-row grid with exactly twelve equal cells in row-major order. Place exactly one subject centered in every cell. Keep every opaque silhouette fully inside its cell with a generous uniform safe margin. Use the same crisp hard-edged pixel scale across all cells, no antialiasing, no gradients, no soft painting, and no 3D rendering. The entire background must be perfectly flat solid chroma magenta #FF00FF with no grid lines, borders, texture, lighting variation, floor plane, shadow, glow, halo, or detached particles. Do not use #FF00FF or near-magenta pixels inside any subject.

Exact cell order:
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

The three hero cells must depict exactly the same character and differ only by one or two pixels of torso, shoulder, cape, or clothing movement that reads as gentle breathing. Do not move the feet, change equipment, alter facial identity, or change canvas scale. Design every icon for recognition at 12 to 20 points using chunky silhouettes, dark charcoal outlines, slate stone neutrals, muted blue, warm gold for victory, restrained red-orange for warning or deletion, and teal only as a small guide accent. Do not depend on thin strokes or tiny internal marks. No text, letters, numbers, logos, UI panels, buttons, scenery, signatures, watermarks, repeated subjects, gore, or reference-app imitation.
```

- [ ] **Step 2: Inspect the source without editing it**

Use the image viewer at original detail and confirm all of the following:

- twelve and only twelve occupied cells;
- the three heroes retain the approved identity and anchored feet;
- inhale and exhale are subtle but distinguishable;
- all nine icon meanings are recognizable at thumbnail size;
- no subject crosses a cell boundary;
- the background is uniform magenta;
- no text, signature, watermark, extra object, shadow, or copied expression appears.

Expected: one coherent sheet that can be reviewed without cropping or cleanup.

- [ ] **Step 3: Present the unsplit sheet and stop for approval**

Show the complete source sheet to the user.
Do not copy it into the worktree, remove its background, crop a cell, edit Swift, or mark this task complete until the user explicitly approves it.

### Task 2: Extract Approved Assets And Record Provenance

**Files:**

- Create: `QuestKeeper/Assets.xcassets/sprite-hero-breathe-in.imageset/Contents.json`
- Create: `QuestKeeper/Assets.xcassets/sprite-hero-breathe-in.imageset/sprite-hero-breathe-in.png`
- Create: `QuestKeeper/Assets.xcassets/sprite-hero-breathe-out.imageset/Contents.json`
- Create: `QuestKeeper/Assets.xcassets/sprite-hero-breathe-out.imageset/sprite-hero-breathe-out.png`
- Replace: `QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/sprite-hero-idle.png`
- Create: `QuestKeeper/Assets.xcassets/icon-battle-flag.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-victory-trophy.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-add.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-notifications-disabled.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-retry.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-complete.imageset/`
- Create: `QuestKeeper/Assets.xcassets/icon-delete.imageset/`
- Create: `QuestKeeperWidget/Assets.xcassets/icon-complete.imageset/`
- Create: `QuestKeeperWidget/Assets.xcassets/icon-stale-warning.imageset/`
- Create: `QuestKeeperWidget/Assets.xcassets/icon-protection-shield.imageset/`
- Create: `docs/notes/011-pixel-ui-asset-generation.md`
- Temporary only: `tmp/imagegen/and-44-source.png`
- Temporary only: `tmp/imagegen/and-44-transparent.png`

**Interfaces:**

- Consumes: the exact source approved in Task 1.
- Produces: transparent fixed-canvas PNGs with the asset names declared by Spec 011 and a provenance record containing the final prompt and source SHA-256.

- [ ] **Step 1: Copy and checksum the approved source**

Copy the exact tool-reported generated image into `tmp/imagegen/and-44-source.png` without resampling.
Run:

```bash
shasum -a 256 tmp/imagegen/and-44-source.png
sips -g pixelWidth -g pixelHeight tmp/imagegen/and-44-source.png
```

Expected: one SHA-256 value and the original pixel dimensions.
Record both values for the generation note.

- [ ] **Step 2: Remove the chroma key after approval**

Run:

```bash
python /Users/dongminyu/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py \
  --input tmp/imagegen/and-44-source.png \
  --output tmp/imagegen/and-44-transparent.png
```

Expected: an RGBA PNG with transparent cell backgrounds and no visible magenta fringe.

- [ ] **Step 3: Split the transparent sheet without resampling**

Use a temporary Pillow environment only for mechanical cropping.
The script computes rounded cumulative four-by-three boundaries, crops without resize, centers each crop on a square transparent canvas, and writes the exact target filenames:

```bash
uv run --with pillow python - <<'PY'
from pathlib import Path
from PIL import Image

source = Image.open("tmp/imagegen/and-44-transparent.png").convert("RGBA")
width, height = source.size
xs = [round(width * index / 4) for index in range(5)]
ys = [round(height * index / 3) for index in range(4)]
names = [
    "sprite-hero-idle",
    "sprite-hero-breathe-in",
    "sprite-hero-breathe-out",
    "icon-battle-flag",
    "icon-victory-trophy",
    "icon-add",
    "icon-notifications-disabled",
    "icon-retry",
    "icon-complete",
    "icon-delete",
    "icon-stale-warning",
    "icon-protection-shield",
]
app_names = set(names[:10])
widget_names = {"icon-complete", "icon-stale-warning", "icon-protection-shield"}

for index, name in enumerate(names):
    row, column = divmod(index, 4)
    crop = source.crop((xs[column], ys[row], xs[column + 1], ys[row + 1]))
    side = max(crop.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    if name in app_names:
        path = Path("QuestKeeper/Assets.xcassets") / f"{name}.imageset" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(path)
    if name in widget_names:
        path = Path("QuestKeeperWidget/Assets.xcassets") / f"{name}.imageset" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(path)
PY
```

Expected: ten app PNGs and three widget PNGs, with `icon-complete` copied from identical source pixels into both catalogs.

- [ ] **Step 4: Add each imageset manifest**

Create `Contents.json` in every new imageset with the corresponding PNG filename in the `1x` universal slot and empty `2x` and `3x` universal slots:

```json
{
  "images" : [
    {
      "filename" : "icon-battle-flag.png",
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

Apply the same exact structure with each imageset's own basename as its `1x` filename.
Use `apply_patch` for manifests and do not edit Xcode-generated asset symbol files.

- [ ] **Step 5: Validate every extracted image**

Run an isolated validation script:

```bash
uv run --with pillow python - <<'PY'
from pathlib import Path
from PIL import Image

roots = [Path("QuestKeeper/Assets.xcassets"), Path("QuestKeeperWidget/Assets.xcassets")]
targets = sorted(path for root in roots for path in root.glob("*.imageset/*.png") if path.name.startswith(("icon-", "sprite-hero-breathe")) or path.name == "sprite-hero-idle.png")
assert len(targets) == 13, len(targets)
for path in targets:
    image = Image.open(path).convert("RGBA")
    assert image.width == image.height, (path, image.size)
    alpha = image.getchannel("A")
    assert alpha.getbbox() is not None, path
    assert alpha.getextrema()[0] == 0, path
print(f"validated {len(targets)} transparent square assets")
PY
```

Expected: `validated 13 transparent square assets`.
Inspect a contact sheet at original detail for fringe, cell bleed, mapping errors, and hero anchor consistency.

- [ ] **Step 6: Record generation provenance**

Create `docs/notes/011-pixel-ui-asset-generation.md` with the approved prompt from Task 1, approval date, source SHA-256, original dimensions, exact row-major mapping, chroma-key command, crop boundaries, and any edge correction performed.
Use sentence-level line breaks, no hard wraps, and a language identifier on every fenced block.

- [ ] **Step 7: Commit approved assets and provenance by concern**

Run:

```bash
git add QuestKeeper/Assets.xcassets QuestKeeperWidget/Assets.xcassets
git diff --staged --check
git commit -m "feat(assets): add approved pixel UI artwork"
git add docs/notes/011-pixel-ui-asset-generation.md
git diff --staged --check
git commit -m "docs(ui): record pixel UI asset generation"
```

Expected: two commits containing only approved final assets and their generation record.

### Task 3: Add Tested Artwork And Animation Contracts

**Files:**

- Modify: `QuestKeeper/Views/DungeonArtwork.swift`
- Modify: `QuestKeeper/Views/HeroSprite.swift`
- Modify: `QuestKeeperTests/DungeonArtworkTests.swift`

**Interfaces:**

- Consumes: app asset names created in Task 2.
- Produces: `DungeonArtwork` cases, `HeroAnimation.breathingFrames`, and `HeroAnimation.artwork(isMourning:reduceMotion:frameIndex:)` for later view integration.

- [ ] **Step 1: Write failing animation and inventory tests**

Add these tests to `DungeonArtworkTests`:

```swift
@Test("breathing uses three unique hero frames in a smooth loop")
func breathingSequence() {
    #expect(HeroAnimation.breathingFrames == [
        .heroIdle,
        .heroBreatheIn,
        .heroBreatheOut,
        .heroBreatheIn,
    ])
    #expect(Set(HeroAnimation.breathingFrames).count == 3)
}

@Test("mourning and Reduce Motion select stable artwork")
func staticHeroArtwork() {
    #expect(HeroAnimation.artwork(isMourning: true, reduceMotion: false, frameIndex: 2) == .heroMourning)
    #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: true, frameIndex: 2) == .heroIdle)
    #expect(HeroAnimation.artwork(isMourning: false, reduceMotion: false, frameIndex: 2) == .heroBreatheOut)
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonArtworkTests
```

Expected: FAIL because `HeroAnimation`, `heroBreatheIn`, and `heroBreatheOut` do not exist.

- [ ] **Step 3: Extend the app artwork enum**

Add these cases to `DungeonArtwork`:

```swift
case heroBreatheIn = "sprite-hero-breathe-in"
case heroBreatheOut = "sprite-hero-breathe-out"
case battleFlag = "icon-battle-flag"
case victoryTrophy = "icon-victory-trophy"
case add = "icon-add"
case notificationsDisabled = "icon-notifications-disabled"
case retry = "icon-retry"
case complete = "icon-complete"
case delete = "icon-delete"
```

Add this pure animation mapping below `DungeonArtwork`:

```swift
nonisolated enum HeroAnimation {
    static let breathingFrames: [DungeonArtwork] = [
        .heroIdle,
        .heroBreatheIn,
        .heroBreatheOut,
        .heroBreatheIn,
    ]

    static func artwork(isMourning: Bool, reduceMotion: Bool, frameIndex: Int) -> DungeonArtwork {
        if isMourning {
            return .heroMourning
        }
        guard !reduceMotion else {
            return .heroIdle
        }
        return breathingFrames[frameIndex % breathingFrames.count]
    }
}
```

- [ ] **Step 4: Add the cancellable breathing loop**

Update `HeroSprite` with view-local state and a task keyed by whether breathing should run:

```swift
@State private var frameIndex = 0

private var shouldBreathe: Bool {
    !isMourning && !reduceMotion
}

private var artwork: DungeonArtwork {
    HeroAnimation.artwork(
        isMourning: isMourning,
        reduceMotion: reduceMotion,
        frameIndex: frameIndex
    )
}
```

Pass `artwork` to `DungeonArtworkView` and attach this task after the existing state animation modifiers:

```swift
.task(id: shouldBreathe) {
    frameIndex = 0
    guard shouldBreathe else { return }
    while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        frameIndex = (frameIndex + 1) % HeroAnimation.breathingFrames.count
    }
}
```

- [ ] **Step 5: Run focused tests and commit**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/DungeonArtworkTests
git diff --check
```

Expected: focused tests pass and the diff check is clean.
Commit:

```bash
git add QuestKeeper/Views/DungeonArtwork.swift QuestKeeper/Views/HeroSprite.swift QuestKeeperTests/DungeonArtworkTests.swift
git commit -m "feat(ui): animate the pixel hero breathing loop"
```

### Task 4: Replace App SF Symbols

**Files:**

- Modify: `QuestKeeper/Views/HeroHeader.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`
- Modify: `QuestKeeper/Views/QuestResolutionView.swift`

**Interfaces:**

- Consumes: the seven app icon cases from Task 3.
- Produces: app controls and status views with no `systemName` or `systemImage` initializer use.

- [ ] **Step 1: Replace HUD stats with typed artwork**

Change `HeroStat.icon` from `String` to `DungeonArtwork` and render it with `DungeonArtworkView(artwork: icon, size: 14)`.
Pass `.battleFlag` and `.victoryTrophy` from `HeroHeader` and keep the existing combined accessibility labels.

- [ ] **Step 2: Replace board, empty-state, and notification symbols**

Use `DungeonArtworkView(artwork: .add, size: 18)` inside the existing `36`-point toolbar button.
Use `.battleFlag` at `34` points for the empty state.
Use custom `Label` closures with `.add` at `16` points and `.notificationsDisabled` at `16` points while retaining the exact existing Korean text and button styles.

- [ ] **Step 3: Replace swipe action symbols**

Change `actionButton` to accept `artwork: DungeonArtwork`.
Build its label as:

```swift
Label {
    Text(title)
} icon: {
    DungeonArtworkView(artwork: artwork, size: 14)
}
```

Pass `.complete` for 완료 and `.delete` for 삭제.
Keep the current background colors, dimensions, actions, and accessibility actions.

- [ ] **Step 4: Replace both retry symbols**

In `DailyGraveRow` and `QuestResolutionView`, replace the system-image labels with custom labels containing `DungeonArtworkView(artwork: .retry, size: 14)` and the unchanged `내일 도전하기` text.

- [ ] **Step 5: Prove app symbols are gone and commit**

Run:

```bash
! rg -n 'Image\(systemName:|Label\([^\n]*systemImage:' QuestKeeper
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
```

Expected: the search returns no matches, the app builds, and the diff check is clean.
Commit:

```bash
git add QuestKeeper/Views/HeroHeader.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestResolutionView.swift
git commit -m "feat(ui): replace app symbols with pixel artwork"
```

### Task 5: Replace Widget SF Symbols

**Files:**

- Modify: `QuestKeeperWidget/WidgetDungeonView.swift`

**Interfaces:**

- Consumes: the three widget assets created in Task 2.
- Produces: widget-local `WidgetArtwork`, `WidgetArtworkView`, and symbol-free footer and completion controls.

- [ ] **Step 1: Add the widget-local artwork seam**

Add below `WidgetDungeonView`:

```swift
private enum WidgetArtwork: String, CaseIterable {
    case complete = "icon-complete"
    case staleWarning = "icon-stale-warning"
    case protectionShield = "icon-protection-shield"
}

private struct WidgetArtworkView: View {
    let artwork: WidgetArtwork
    let size: CGFloat

    var body: some View {
        Image(decorative: artwork.rawValue)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
```

- [ ] **Step 2: Replace footer and completion symbols**

Render `entry.state.isStale ? .staleWarning : .protectionShield` at `12` points in the footer.
Render `.complete` at `13` points for compact rows and `12` points otherwise inside the existing completion button frame.
Keep the explicit `완료` accessibility label and all existing widget intent behavior.

- [ ] **Step 3: Prove widget symbols are gone and commit**

Run:

```bash
! rg -n 'Image\(systemName:|Label\([^\n]*systemImage:' QuestKeeperWidget
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
```

Expected: the search returns no matches, the widget builds, and the diff check is clean.
Commit:

```bash
git add QuestKeeperWidget/WidgetDungeonView.swift
git commit -m "feat(widget): replace symbols with pixel artwork"
```

### Task 6: Full Verification And Visual QA

**Files:**

- Modify only if verified evidence requires a scoped correction to a file already listed above.

**Interfaces:**

- Consumes: all implementation tasks.
- Produces: evidence that tests, builds, source guards, accessibility behavior, and visual states satisfy Spec 011.

- [ ] **Step 1: Run automated verification**

Run one heavy Xcode job at a time:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
git diff --check
! rg -n 'Image\(systemName:|Label\([^\n]*systemImage:' QuestKeeper QuestKeeperWidget
```

Expected: tests and both builds succeed, the diff check is clean, and the source guard returns no matches.

- [ ] **Step 2: Run simulator visual QA**

Launch the app and inspect:

- multiple breathing cycles with anchored feet and stable HUD geometry;
- static idle under Reduce Motion;
- static mourning presentation and unchanged accessibility state;
- HUD battle and victory stats;
- empty dungeon, both add controls, notification guidance, retry actions, completion rail, and delete rail;
- light and dark mode;
- a large Korean accessibility text size;
- VoiceOver output with no asset filenames or duplicated meanings.

Inspect small and medium widgets in active, empty, stale, and current states and verify the completion intent button keeps its hit area and label.
Use the visual QA skill after capturing the app and widget states.

- [ ] **Step 3: Review the branch diff against Spec 011**

Run:

```bash
git status --short
git diff origin/main...HEAD --stat
git diff origin/main...HEAD -- QuestKeeper QuestKeeperWidget QuestKeeperTests docs
```

Expected: every changed file maps to a plan task, no domain model changed, no generated build output is tracked, and no unrelated file is included.

- [ ] **Step 4: Record any verification-only correction**

If visual QA finds a scoped defect, reproduce it, add or adjust the narrowest relevant test where possible, apply only the correction, rerun the affected focused check, and commit it with a conventional `fix(ui):` or `fix(widget):` message that names the behavior.
If no correction is needed, create no empty commit.

- [ ] **Step 5: Report completion state**

Report all commit hashes, test and build outcomes, manual states actually observed, remaining uncommitted files, and the Linear issue status.
Do not claim a visual or accessibility state was verified unless it was actually observed.
