# Combat Assets And Hero Customization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand QuestKeeper to nine stable monster variants, two gender presentations and four hair colors, a native appearance sheet, visible hero breathing, and a fixed-size sword-strike battle scene.

**Architecture:** Keep monster identity and battle phases derived through small pure value types, keep appearance preferences outside SwiftData in app preferences, and keep transient animation ownership in SwiftUI views. Preserve the existing app and widget asset-catalog split, generate runtime PNGs only from user-approved source sheets, and add no runtime image processing or third-party dependency.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, SwiftData raw-facts model, WidgetKit, asset catalogs, built-in image generation, ImageMagick for deterministic development-time extraction and palette replacement, Trunk.

## Global Constraints

- Deployment target remains iOS 26.5.
- Do not add fields to `Quest`, `QuestSnapshot`, `HeroState`, widget payloads, retention events, notification payloads, or CloudKit schema.
- Do not persist monster type, battle phase, frame index, or artwork names.
- Do not add SpriteKit, SceneKit, a general animation engine, runtime image processing, or a third-party dependency.
- Preserve the current male-presenting blue-haired hero as the default.
- Preserve completion timestamps captured when the user acts, not when animation finishes.
- Keep the quest-row minimum height and neighboring layout stable during battle.
- Respect Reduce Motion, Dynamic Type, VoiceOver, light mode, and dark mode.
- Do not extract, recolor, or integrate either source sheet before explicit user approval.
- Keep app and widget runtime asset catalogs target-local.
- Use original QuestKeeper artwork and do not imitate another game's protected expression.
- Keep the hero right-facing and author every monster in a left-facing or left-biased pose toward the hero.

## Execution Workspace

Generate and review the two preview sheets without repository writes.
After the user approves both sheets, use `superpowers:using-git-worktrees` to create an isolated worktree on `feat/combat-assets-customization` from the commit containing this plan and execute Tasks 2-7 there.
Do not begin Swift or asset-catalog implementation on `main`.

---

## File Map

### New files

- `QuestKeeperShared/MonsterArtworkSelection.swift`: shared pure monster family and UUID selection policy.
- `QuestKeeper/Models/HeroAppearance.swift`: typed gender, hair color, preference keys, and fallback decoding.
- `QuestKeeper/Views/HeroArtwork.swift`: typed hero frame and runtime asset-name construction.
- `QuestKeeper/Views/HeroAppearanceSheet.swift`: native item-driven appearance settings sheet.
- `QuestKeeper/Views/QuestBattleScene.swift`: fixed-size hero-versus-monster row scene.
- `QuestKeeperTests/MonsterArtworkSelectionTests.swift`: stable family and UUID selection coverage.
- `QuestKeeperTests/HeroAppearanceTests.swift`: appearance decoding and artwork-name coverage.
- `scripts/process-combat-assets.sh`: deterministic sheet extraction, chroma removal, hair palette replacement, and catalog output.
- `scripts/test-combat-assets.sh`: validates source inputs, runtime asset inventory, manifests, dimensions, alpha, and frame alignment.
- `docs/notes/017-combat-asset-generation.md`: approved prompt, source paths, checksums, cell mapping, palette mapping, and corrections.

### Modified files

- `QuestKeeper/Views/DungeonArtwork.swift`: nine monster cases and quest-aware selection.
- `QuestKeeper/Views/HeroSprite.swift`: typed appearance and enlarged stable breathing frames.
- `QuestKeeper/Views/HeroHeader.swift`: appearance input and explicit 44-point `외형` action.
- `QuestKeeper/Views/HomeDungeonBoardView.swift`: app-preference ownership and local sheet destination.
- `QuestKeeper/Views/QuestListSections.swift`: pass appearance into quest rows and cancel battle tasks on disappearance.
- `QuestKeeper/Views/QuestRow.swift`: quest-aware monster selection, fixed battle stage, and phase accessibility values.
- `QuestKeeper/Views/QuestBattleResolution.swift`: four phases and exact thresholds.
- `QuestKeeperWidget/WidgetDungeonView.swift`: quest-aware nine-monster selection.
- `QuestKeeperTests/DungeonArtworkTests.swift`: app asset-name and animation-frame catalog coverage.
- `QuestKeeperTests/QuestBattleResolutionTests.swift`: wind-up, striking, defeated, and timing boundaries.
- `QuestKeeper/Assets.xcassets/**`: nine monster images and forty hero frame variants after approval.
- `QuestKeeperWidget/Assets.xcassets/**`: nine monster images after approval.

### Removed after migration

- `QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset/**`
- `QuestKeeper/Assets.xcassets/sprite-hero-breathe-in.imageset/**`
- `QuestKeeper/Assets.xcassets/sprite-hero-breathe-out.imageset/**`
- `QuestKeeper/Assets.xcassets/sprite-hero-mourning.imageset/**`

Use the selected appearance's idle frame with the existing mourning scale, rotation, and offset treatment.
This preserves the selected gender and hair color without inventing sixteen unapproved mourning frames.

---

### Task 1: Generate And Approve Source Sheets

**Files:**

- Reference: `docs/assets/pixel-home-dungeon/questkeeper-home-dungeon-sheet-transparent.png`
- Preview only: built-in image-generation output paths
- Create after approval: `docs/notes/017-combat-asset-generation.md`

**Interfaces:**

- Consumes: the approved current QuestKeeper hero, slime, skeleton, and dragon artwork as identity and style references.
- Produces: one unsplit three-by-three monster source sheet and one unsplit five-column-by-two-row hero source sheet approved by the user.

- [ ] **Step 1: Generate the monster source sheet**

Use built-in image generation with the current transparent dungeon sheet as a style and identity reference.
Request exactly this row-major order:

```plaintext
slime, bat, mushroom
skeleton, orc, mimic
dragon, golem, lich
```

Require a strict three-by-three equal grid, one centered subject per cell, a perfectly flat `#FF00FF` background, uniform safe margins, the existing QuestKeeper outline weight and palette, and no grid lines, text, scenery, particles, shadows, gradients, signatures, or cell crossings.
Every monster uses a left-facing or left-biased three-quarter pose while preserving its identity, silhouette, equipment, and cell center.

- [ ] **Step 2: Generate the hero source sheet**

Use built-in image editing with the current QuestKeeper hero as the identity reference.
Request exactly this row-major order:

```plaintext
male idle, male breathe-in, male breathe-out, male wind-up, male strike
female idle, female breathe-in, female breathe-out, female wind-up, female strike
```

Require a strict five-column-by-two-row equal grid, anchored feet and horizontal centers, the same blue hair palette in all ten cells, consistent armor and sword, readable poses at a 36-point battle size, a perfectly flat `#FF00FF` background, and no grid lines, text, extra objects, shadows, gradients, signatures, or cell crossings.

- [ ] **Step 3: Inspect the unsplit sheets**

Open both outputs at original resolution and check subject count, row-major order, identity, pose continuity, silhouette readability, background uniformity, safe margins, and forbidden content.
Reject the whole sheet or request one targeted edit when any requirement fails.

- [ ] **Step 4: Present both sheets and stop for explicit approval**

Show both unsplit sheets inline with their full prompts and source paths.
Do not copy either image into the repository, extract cells, recolor hair, edit Swift, or create runtime asset catalogs before the user approves both sheets.

- [ ] **Step 5: Record approved sources**

After approval, write `docs/notes/017-combat-asset-generation.md` with the final prompts, built-in tool mode, generated source paths, dimensions, SHA-256 values, cell order, and any targeted revision decisions.

- [ ] **Step 6: Commit the approved source record with the later extracted assets**

Do not create a standalone source-record commit that leaves the repository without the runtime assets it describes.
Task 4 commits the source record, processing scripts, and generated assets as one reproducible asset concern.

---

### Task 2: Add Stable Shared Monster Selection

**Files:**

- Create: `QuestKeeperShared/MonsterArtworkSelection.swift`
- Create: `QuestKeeperTests/MonsterArtworkSelectionTests.swift`
- Modify: `QuestKeeper/Views/DungeonArtwork.swift`
- Modify: `QuestKeeperWidget/WidgetDungeonView.swift`

**Interfaces:**

- Consumes: `mobLevel: Int` and `questID: UUID`.
- Produces: `MonsterKind`, `MonsterFamily`, `MonsterArtworkSelection.family(forMobLevel:)`, `MonsterArtworkSelection.variantIndex(forQuestID:)`, and `MonsterArtworkSelection.monster(forMobLevel:questID:)`.

- [ ] **Step 1: Write failing selection tests**

Create tests with these expectations:

```swift
import Foundation
import Testing
@testable import QuestKeeper

@Suite("Monster artwork selection")
struct MonsterArtworkSelectionTests {
    @Test("mob levels map to three visual families")
    func familyMapping() {
        #expect(MonsterArtworkSelection.family(forMobLevel: 0) == .low)
        #expect(MonsterArtworkSelection.family(forMobLevel: 1) == .low)
        #expect(MonsterArtworkSelection.family(forMobLevel: 2) == .medium)
        #expect(MonsterArtworkSelection.family(forMobLevel: 3) == .medium)
        #expect(MonsterArtworkSelection.family(forMobLevel: 4) == .high)
        #expect(MonsterArtworkSelection.family(forMobLevel: 5) == .high)
    }

    @Test("fixed UUIDs reach all family variants")
    func stableVariants() {
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ]
        #expect(ids.map(MonsterArtworkSelection.variantIndex(forQuestID:)) == [0, 1, 2])
    }

    @Test("selection stays inside the level family")
    func selectedKinds() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        #expect(MonsterArtworkSelection.monster(forMobLevel: 0, questID: id) == .bat)
        #expect(MonsterArtworkSelection.monster(forMobLevel: 2, questID: id) == .orc)
        #expect(MonsterArtworkSelection.monster(forMobLevel: 4, questID: id) == .golem)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/MonsterArtworkSelectionTests -quiet
```

Expected: FAIL because `MonsterArtworkSelection` does not exist.

- [ ] **Step 3: Implement the shared pure selection policy**

Create these types in `QuestKeeperShared/MonsterArtworkSelection.swift`:

```swift
import Foundation

nonisolated enum MonsterFamily: Sendable, Equatable {
    case low
    case medium
    case high
}

nonisolated enum MonsterKind: String, CaseIterable, Sendable {
    case slime
    case bat
    case mushroom
    case skeleton
    case orc
    case mimic
    case dragon
    case golem
    case lich

    var assetName: String { "sprite-\(rawValue)" }

    var localizedName: String {
        switch self {
        case .slime: "슬라임"
        case .bat: "박쥐"
        case .mushroom: "버섯"
        case .skeleton: "스켈레톤"
        case .orc: "오크"
        case .mimic: "미믹"
        case .dragon: "드래곤"
        case .golem: "골렘"
        case .lich: "리치"
        }
    }
}

nonisolated enum MonsterArtworkSelection {
    static func family(forMobLevel level: Int) -> MonsterFamily {
        switch level {
        case ..<2: .low
        case 2..<4: .medium
        default: .high
        }
    }

    static func variantIndex(forQuestID questID: UUID) -> Int {
        withUnsafeBytes(of: questID.uuid) { bytes in
            bytes.reduce(0) { ($0 + Int($1)) % 3 }
        }
    }

    static func monster(forMobLevel level: Int, questID: UUID) -> MonsterKind {
        let index = variantIndex(forQuestID: questID)
        switch family(forMobLevel: level) {
        case .low: [.slime, .bat, .mushroom][index]
        case .medium: [.skeleton, .orc, .mimic][index]
        case .high: [.dragon, .golem, .lich][index]
        }
    }
}
```

- [ ] **Step 4: Update target-local artwork mappings**

Add nine monster cases to `DungeonArtwork` and `WidgetArtwork`.
Replace both `monster(level:)` methods with `monster(level:questID:)` methods that switch exhaustively over `MonsterArtworkSelection.monster(forMobLevel:questID:)`.
Update `QuestRow` and widget `MobBadge` call sites to pass `quest.id` or `mob.id`.

- [ ] **Step 5: Run focused tests and build both targets**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/MonsterArtworkSelectionTests -quiet
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: tests pass; builds may not yet render the six new names until Task 4 adds assets, but asset-catalog compilation remains valid because unresolved `Image` names are runtime lookups.

- [ ] **Step 6: Commit the shared selection concern**

```bash
git add QuestKeeperShared/MonsterArtworkSelection.swift QuestKeeperTests/MonsterArtworkSelectionTests.swift QuestKeeper/Views/DungeonArtwork.swift QuestKeeper/Views/QuestRow.swift QuestKeeperWidget/WidgetDungeonView.swift
git diff --staged --check
git commit -m "feat(assets): derive stable monster variants"
```

---

### Task 3: Add Typed Hero Appearance And Artwork Names

**Files:**

- Create: `QuestKeeper/Models/HeroAppearance.swift`
- Create: `QuestKeeper/Views/HeroArtwork.swift`
- Create: `QuestKeeperTests/HeroAppearanceTests.swift`
- Modify: `QuestKeeper/Views/HeroSprite.swift`
- Modify: `QuestKeeperTests/DungeonArtworkTests.swift`

**Interfaces:**

- Consumes: raw preference strings, `HeroAppearance`, `HeroFrame`, mourning state, Reduce Motion, and breathing index.
- Produces: `HeroGender`, `HeroHairColor`, `HeroAppearance`, `HeroAppearance.StorageKey`, `HeroFrame`, `HeroArtwork.assetName(appearance:frame:)`, and `HeroAnimation.frame(isMourning:reduceMotion:frameIndex:)`.

- [ ] **Step 1: Write failing appearance tests**

Create these behavior checks:

```swift
import Testing
@testable import QuestKeeper

@Suite("Hero appearance")
struct HeroAppearanceTests {
    @Test("unknown stored values fall back to the current hero")
    func fallback() {
        #expect(HeroAppearance(genderRawValue: "unknown", hairColorRawValue: "unknown") == .default)
        #expect(HeroAppearance.default == HeroAppearance(gender: .male, hairColor: .blue))
    }

    @Test("every appearance resolves five unique asset names")
    func completeArtworkCatalog() {
        for gender in HeroGender.allCases {
            for hairColor in HeroHairColor.allCases {
                let appearance = HeroAppearance(gender: gender, hairColor: hairColor)
                let names = Set(HeroFrame.allCases.map { HeroArtwork.assetName(appearance: appearance, frame: $0) })
                #expect(names.count == 5)
            }
        }
    }

    @Test("default asset names preserve the current visual identity")
    func defaultNames() {
        #expect(HeroArtwork.assetName(appearance: .default, frame: .idle) == "sprite-hero-male-blue-idle")
        #expect(HeroArtwork.assetName(appearance: .default, frame: .strike) == "sprite-hero-male-blue-strike")
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/HeroAppearanceTests -quiet
```

Expected: FAIL because the appearance types do not exist.

- [ ] **Step 3: Implement typed appearance and fallback decoding**

Create `HeroAppearance.swift` with `String`, `CaseIterable`, and `Sendable` enums.
Expose Korean titles in the model because they are stable product copy used by native pickers.

```swift
nonisolated enum HeroGender: String, CaseIterable, Hashable, Sendable {
    case male
    case female

    var title: String { self == .male ? "남성형" : "여성형" }
}

nonisolated enum HeroHairColor: String, CaseIterable, Hashable, Sendable {
    case black
    case brown
    case blue
    case red

    var title: String {
        switch self {
        case .black: "검정"
        case .brown: "갈색"
        case .blue: "파랑"
        case .red: "빨강"
        }
    }
}

nonisolated struct HeroAppearance: Sendable, Equatable {
    static let `default` = HeroAppearance(gender: .male, hairColor: .blue)

    enum StorageKey {
        static let gender = "heroAppearance.gender"
        static let hairColor = "heroAppearance.hairColor"
    }

    let gender: HeroGender
    let hairColor: HeroHairColor

    init(gender: HeroGender, hairColor: HeroHairColor) {
        self.gender = gender
        self.hairColor = hairColor
    }

    init(genderRawValue: String, hairColorRawValue: String) {
        self.gender = HeroGender(rawValue: genderRawValue) ?? .default.gender
        self.hairColor = HeroHairColor(rawValue: hairColorRawValue) ?? .default.hairColor
    }
}
```

- [ ] **Step 4: Implement typed frame and artwork selection**

Create `HeroArtwork.swift`:

```swift
nonisolated enum HeroFrame: String, CaseIterable, Sendable {
    case idle
    case breatheIn = "breathe-in"
    case breatheOut = "breathe-out"
    case windUp = "wind-up"
    case strike
}

nonisolated enum HeroArtwork {
    static func assetName(appearance: HeroAppearance, frame: HeroFrame) -> String {
        "sprite-hero-\(appearance.gender.rawValue)-\(appearance.hairColor.rawValue)-\(frame.rawValue)"
    }
}

nonisolated enum HeroAnimation {
    static let breathingFrames: [HeroFrame] = [.idle, .breatheIn, .breatheOut, .breatheIn]

    static func frame(reduceMotion: Bool, frameIndex: Int) -> HeroFrame {
        reduceMotion ? .idle : breathingFrames[frameIndex % breathingFrames.count]
    }
}
```

When `isMourning` is true, render the selected appearance's idle frame with the existing mourning scale, rotation, and offset treatment.
Do not fall back to a fixed blue-haired image.

- [ ] **Step 5: Update HeroSprite to consume appearance**

Add `let appearance: HeroAppearance` with default `.default` only for previews and compatibility while call sites migrate.
Render the selected runtime name with `Image(decorative:)`, `.interpolation(.none)`, fixed frame, and the existing cancellable breathing task.
Raise the HUD baseline size from 20 points to 36 points in `HeroHeader` so the frame differences are visible.

- [ ] **Step 6: Run focused tests and the app build**

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/HeroAppearanceTests -only-testing:QuestKeeperTests/DungeonArtworkTests -quiet
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Expected: tests pass and the app builds.

- [ ] **Step 7: Commit the appearance model concern**

```bash
git add QuestKeeper/Models/HeroAppearance.swift QuestKeeper/Views/HeroArtwork.swift QuestKeeper/Views/HeroSprite.swift QuestKeeperTests/HeroAppearanceTests.swift QuestKeeperTests/DungeonArtworkTests.swift
git diff --staged --check
git commit -m "feat(hero): add typed appearance artwork"
```

---

### Task 4: Extract And Integrate Approved Runtime Assets

**Files:**

- Create: `scripts/process-combat-assets.sh`
- Create: `scripts/test-combat-assets.sh`
- Create: `docs/notes/017-combat-asset-generation.md`
- Modify: `QuestKeeper/Assets.xcassets/**`
- Modify: `QuestKeeperWidget/Assets.xcassets/**`
- Remove after verified replacement: three generic breathing imagesets listed in the File Map.

**Interfaces:**

- Consumes: two approved unsplit chroma-key sheets and the documented source blue-hair palette.
- Produces: nine app monster imagesets, nine widget monster imagesets, forty app hero imagesets, valid `Contents.json` files, and reproducible validation output.

- [ ] **Step 1: Write the failing asset inventory validator**

Create `scripts/test-combat-assets.sh` with bash 3.2-compatible syntax.
The script must use explicit roots, fail when `magick` is unavailable, enumerate the exact nine monster names and forty hero names, validate each `Contents.json` with `plutil -lint`, and use `magick identify` to require square PNGs with alpha and nonempty opaque bounds.
It must also require all hero frames to share dimensions.

Run:

```bash
/bin/bash -n scripts/test-combat-assets.sh
/bin/bash scripts/test-combat-assets.sh
```

Expected: syntax passes and the inventory check fails because the new imagesets do not exist.

- [ ] **Step 2: Write the deterministic processing script**

Create `scripts/process-combat-assets.sh` with these arguments:

```plaintext
scripts/process-combat-assets.sh monster-source.png hero-source.png output-root
```

The script must:

- resolve and validate each input as a regular PNG;
- validate the approved flat chroma key recorded in the provenance note and remove it with ImageMagick;
- derive rounded cumulative crop boundaries for three-by-three and five-by-two grids;
- crop cells without resizing opaque pixels;
- normalize every extracted cell onto a shared transparent square canvas;
- inspect the approved hero source histogram and replace only the documented blue hair colors with exact black, brown, blue, and red shade maps;
- create target-local imageset directories and `Contents.json` manifests under the explicit output root;
- never write directly into the repository until the temporary output passes `scripts/test-combat-assets.sh`.

Use `mktemp -d` and a cleanup trap for intermediate files.
Do not use bare formatters, wildcard repository roots, or broad find-and-replace.

- [ ] **Step 3: Copy the approved sources into deterministic repository paths**

After approval only, copy the two approved built-in outputs to stable repository-relative paths:

```plaintext
docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png
docs/assets/pixel-combat-customization/questkeeper-heroes-source.png
```

Record the stable generated filenames, original and repository SHA-256 values, and PNG-hook normalization in `docs/notes/017-combat-asset-generation.md`.
Verify pixel identity with ImageMagick `compare -metric AE`; omit machine-specific cache prefixes and session identifiers from the public record.

- [ ] **Step 4: Process into a temporary directory and validate**

```bash
combat_asset_tmp="$(mktemp -d)"
/bin/bash scripts/process-combat-assets.sh docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png docs/assets/pixel-combat-customization/questkeeper-heroes-source.png "$combat_asset_tmp"
/bin/bash scripts/test-combat-assets.sh "$combat_asset_tmp"
```

Expected: both commands exit 0 and print the exact runtime inventory count.

- [ ] **Step 5: Inspect extracted assets visually before repository integration**

Create contact sheets for all nine monsters, both gender presentations across five frames, and all four hair colors.
Open them at original resolution and target-size nearest-neighbor scale.
Reject clipped silhouettes, color bleed, ambiguous hair masks, baseline drift, missing swords, or inconsistent cell mapping.

- [ ] **Step 6: Copy validated outputs into explicit catalogs**

Copy only the validated app imagesets under `QuestKeeper/Assets.xcassets` and widget monster imagesets under `QuestKeeperWidget/Assets.xcassets`.
Remove the four generic hero imagesets only after every migrated call site uses the new names and the validator passes against the repository.

- [ ] **Step 7: Run asset tests and both builds**

```bash
/bin/bash -n scripts/process-combat-assets.sh
/bin/bash -n scripts/test-combat-assets.sh
/bin/bash scripts/test-combat-assets.sh .
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/HeroAppearanceTests -only-testing:QuestKeeperTests/MonsterArtworkSelectionTests -only-testing:QuestKeeperTests/DungeonArtworkTests -quiet
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

- [ ] **Step 8: Commit the complete asset concern**

Stage the two scripts, source record, added imagesets, modified imagesets, and removed orphaned breathing imagesets by explicit path.
Inspect `git diff --staged --stat`, validate destination content for every removed/renamed asset, then commit:

```bash
git commit -m "feat(assets): add combat and hero sprite catalog"
```

---

### Task 5: Add The Native Hero Appearance Sheet

**Files:**

- Create: `QuestKeeper/Views/HeroAppearanceSheet.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/HeroHeader.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**

- Consumes: two `@AppStorage` raw values owned by `HomeDungeonBoardView`.
- Produces: `HomeDungeonSheet.appearance`, typed `Binding<HeroGender>`, typed `Binding<HeroHairColor>`, and explicit `HeroAppearance` propagation to the HUD and battle rows.

- [ ] **Step 1: Add item-driven sheet state and typed preference bindings**

In `HomeDungeonBoardView`, add:

```swift
private enum HomeDungeonSheet: String, Identifiable {
    case appearance
    var id: String { rawValue }
}

@AppStorage(HeroAppearance.StorageKey.gender)
private var heroGenderRawValue = HeroAppearance.default.gender.rawValue

@AppStorage(HeroAppearance.StorageKey.hairColor)
private var heroHairColorRawValue = HeroAppearance.default.hairColor.rawValue

@State private var presentedSheet: HomeDungeonSheet?
```

Derive one `HeroAppearance` from the raw values and pass it explicitly through `BoardHUD`, `HeroHeader`, `QuestListSections`, and `QuestRow`.
Use computed typed bindings that write enum raw values back to the two app-preference strings.

- [ ] **Step 2: Create the native sheet**

Create `HeroAppearanceSheet` with `@Binding var gender: HeroGender`, `@Binding var hairColor: HeroHairColor`, and internal `@Environment(\.dismiss)`.
Use this structure:

```swift
NavigationStack {
    Form {
        Section("미리보기") {
            HeroSprite(appearance: appearance, isMourning: false, size: 96)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
        Section("성별") {
            Picker("성별", selection: $gender) {
                ForEach(HeroGender.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
                .pickerStyle(.segmented)
        }
        Section("머리색") {
            Picker("머리색", selection: $hairColor) {
                ForEach(HeroHairColor.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        }
    }
    .navigationTitle("용사 외형")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button("완료") { dismiss() }
        }
    }
}
```

Use native picker labels and do not replace them with inaccessible custom swatches.

- [ ] **Step 3: Add the explicit HUD action**

Update `HeroHeader` to accept `appearance` and `onEditAppearance`.
Render the hero at 36 points and add a visible `외형` text button with a minimum 44-point hit target.
Keep `ViewThatFits` so compact and accessibility layouts can fall back to the vertical arrangement.

- [ ] **Step 4: Add previews for default, customized, and sheet states**

Add deterministic previews for male-blue, female-red, customized mourning, and the appearance sheet.
Do not use global mutable defaults in previews; bind local preview state.

- [ ] **Step 5: Build and inspect the sheet in previews or simulator**

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

Verify the `외형` action remains reachable with accessibility text and the sheet owns its dismissal.

- [ ] **Step 6: Commit the settings UI concern**

```bash
git add QuestKeeper/Views/HeroAppearanceSheet.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/HeroHeader.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift
git diff --staged --check
git commit -m "feat(hero): add appearance settings"
```

---

### Task 6: Add Four-Phase Sword Battle Presentation

**Files:**

- Modify: `QuestKeeper/Views/QuestBattleResolution.swift`
- Modify: `QuestKeeperTests/QuestBattleResolutionTests.swift`
- Create: `QuestKeeper/Views/QuestBattleScene.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**

- Consumes: `HeroAppearance`, `DungeonArtwork`, `QuestBattlePhase`, Reduce Motion, and the existing completion closure.
- Produces: four exact transition phases and a fixed `100x48` battle stage.

- [ ] **Step 1: Extend tests to specify four exact phase boundaries**

Replace the three-phase expectations with:

```swift
@Test("battle phases progress through wind-up strike and defeat")
func phaseBoundaries() {
    #expect(QuestBattleResolution.phase(elapsed: -0.01) == .idle)
    #expect(QuestBattleResolution.phase(elapsed: 0) == .windUp)
    #expect(QuestBattleResolution.phase(elapsed: 0.179) == .windUp)
    #expect(QuestBattleResolution.phase(elapsed: 0.18) == .striking)
    #expect(QuestBattleResolution.phase(elapsed: 0.419) == .striking)
    #expect(QuestBattleResolution.phase(elapsed: 0.42) == .defeated)
    #expect(QuestBattleResolution.commitDelay == 1.05)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -quiet
```

Expected: FAIL because `.windUp` and the new thresholds do not exist.

- [ ] **Step 3: Implement exact transition policy**

Update the policy to:

```swift
nonisolated enum QuestBattlePhase: Equatable {
    case idle
    case windUp
    case striking
    case defeated
}

nonisolated enum QuestBattleResolution {
    static let strikingPhaseDelay: TimeInterval = 0.18
    static let defeatedPhaseDelay: TimeInterval = 0.42
    static let commitDelay: TimeInterval = 1.05

    static func phase(elapsed: TimeInterval) -> QuestBattlePhase {
        if elapsed < 0 { return .idle }
        if elapsed < strikingPhaseDelay { return .windUp }
        if elapsed < defeatedPhaseDelay { return .striking }
        return .defeated
    }

    static func shouldAcceptCompletion(isResolving: Bool) -> Bool { !isResolving }
}
```

- [ ] **Step 4: Update the row-local task sequence**

`completeWithBattle()` sets `.windUp` immediately, sleeps to `strikingPhaseDelay`, sets `.striking`, sleeps to `defeatedPhaseDelay`, sets `.defeated`, then sleeps the remaining time before calling `onComplete(quest, completedAt)` once.
Add `.onDisappear` cancellation for `battleTask`.
Keep the first action's `Date.now` captured before any sleep.

- [ ] **Step 5: Create the fixed battle scene**

Implement `QuestBattleScene` with a fixed `100x48` frame.
Render the selected hero on the left and quest-aware monster on the right.
Render the approved right-facing hero and left-facing monster without a runtime horizontal mirror, so asymmetric equipment and lighting remain consistent with the approved source art.
Use `.windUp` to select the wind-up frame, `.striking` to select the strike frame and show `battleImpact`, and `.defeated` to keep the strike pose while fading the monster.
When Reduce Motion is false, apply only phase-signaling lunge, recoil, rotation, and scale transforms.
When Reduce Motion is true, force all offsets, rotations, and scales to neutral while preserving frame and opacity changes.

- [ ] **Step 6: Add localized accessibility phase values**

Map `.idle` to an empty value, `.windUp` to `공격 준비 중`, `.striking` to `공격 중`, and `.defeated` to `승리 처리 중`.
Use `MonsterKind` to expose the localized monster name plus its level.
Decorative hero, impact, and sword layers remain hidden from accessibility.

- [ ] **Step 7: Run focused tests and app build**

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestBattleResolutionTests -only-testing:QuestKeeperTests/QuestActionsTests -quiet
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -quiet
```

- [ ] **Step 8: Commit the battle presentation concern**

```bash
git add QuestKeeper/Views/QuestBattleResolution.swift QuestKeeperTests/QuestBattleResolutionTests.swift QuestKeeper/Views/QuestBattleScene.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift
git diff --staged --check
git commit -m "feat(combat): show hero sword battle scene"
```

---

### Task 7: Complete Regression Verification And Manual QA

**Files:**

- Modify only files required by concrete failures caused by Tasks 2-6.
- Create evidence under a temporary or ignored QA directory, not committed app assets.

**Interfaces:**

- Consumes: the complete implementation and approved runtime assets.
- Produces: green diagnostics, tests, builds, scheduler-independent simulator evidence, and fresh visual QA verdicts.

- [ ] **Step 1: Run formatting and static checks on explicit paths**

```bash
trunk check QuestKeeperShared/MonsterArtworkSelection.swift QuestKeeper/Models/HeroAppearance.swift QuestKeeper/Views/HeroArtwork.swift QuestKeeper/Views/HeroAppearanceSheet.swift QuestKeeper/Views/QuestBattleScene.swift QuestKeeper/Views/DungeonArtwork.swift QuestKeeper/Views/HeroSprite.swift QuestKeeper/Views/HeroHeader.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestBattleResolution.swift QuestKeeperWidget/WidgetDungeonView.swift QuestKeeperTests/MonsterArtworkSelectionTests.swift QuestKeeperTests/HeroAppearanceTests.swift QuestKeeperTests/DungeonArtworkTests.swift QuestKeeperTests/QuestBattleResolutionTests.swift scripts/process-combat-assets.sh scripts/test-combat-assets.sh docs/notes/017-combat-asset-generation.md
git diff --check
```

- [ ] **Step 2: Run the complete unit-test target once**

```bash
xcodebuild test -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests
```

Expected: exit 0 with no failing QuestKeeperTests.

- [ ] **Step 3: Build app and widget once**

```bash
xcodebuild build -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild build -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: both commands exit 0.

- [ ] **Step 4: Launch the real app and exercise the complete surface**

Boot only the iPhone 17e simulator.
Install and launch the current app build.
Create low-, medium-, and high-level quests, verify stable monster selection, open the appearance sheet, exercise all eight appearance combinations, relaunch to confirm persistence, and complete a quest while observing wind-up, strike, impact, defeat, reward, and removal.
Enable Reduce Motion and repeat completion to confirm no travel, rotation, scale, or spring motion.

- [ ] **Step 5: Capture fresh motion and layout evidence**

Capture every required surface and state after the last UI edit:

```plaintext
HUD: rest, breathing midpoint, next breathing frame
Appearance sheet: male-blue default, female-red customized, accessibility text layout
Battle: wind-up, strike midpoint, defeated settled
Reduce Motion battle: wind-up, strike, defeated
Widget: low, medium, and high monster families
```

Verify image signatures, dimensions, and complete compositing before review.

- [ ] **Step 6: Run two independent visual QA passes**

Dispatch the required read-only design-system/functional-integrity pass and visual/CJK-precision pass with every enumerated capture, current source, and motion observations.
If either returns a product blocker, fix only the located issue, recapture every affected state, and dispatch fresh reviewers.
If either returns an evidence blocker, repair only the capture pipeline, reshoot, and dispatch fresh reviewers.
Continue until both pass on the same current build.

- [ ] **Step 7: Verify final Git state and commits**

```bash
git status --short
git log --oneline --decorate -8
git diff origin/main...HEAD --check
```

Account for every remaining file and do not include temporary captures in commits.

- [ ] **Step 8: Use the finishing-development-branch workflow**

Follow `superpowers:finishing-a-development-branch` after all tests, builds, asset checks, manual QA, and independent visual reviews pass.
Do not push unless the user explicitly requests it.
