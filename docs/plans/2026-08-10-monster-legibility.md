# Monster Legibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the rule behind a quest's monster readable — mark rows whose monster grew while the app was closed, and let a tap on the monster explain why it is that monster.

**Architecture:** One new derived field on `HeroState` (`escalationsWhileAway`), computed by evaluating the existing pure `mobLevel(at:)` at two instants and carried through the activation-replay path that `deathsWhileAway` already uses. Two presentation surfaces consume it: a pill on the row and a sheet opened from the monster sprite. No stored state is added to `Quest`.

**Tech Stack:** SwiftUI, SwiftData (`@Model`, `@Query`), Swift Testing (`import Testing`, `@Test`, `#expect`) for unit tests, XCTest for UI tests, String Catalogs (`.xcstrings`).

Spec: `docs/specs/019-monster-legibility.md`. Linear: AND-114. Branch: `ydm2790/and-114-monster-legibility`.

## Global Constraints

- **Persist facts only, derive state.** Never add a derived field to the `Quest` `@Model`. After every task the guard must return nothing: `! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift`
- **Swift 6 strict concurrency.** `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`. No new warnings.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — extensions of the string namespaces must be written `nonisolated extension`.
- **Naming:** derivation/action namespaces are caseless `nonisolated enum`; state values are `nonisolated struct`.
- **Unit tests are Swift Testing**, not XCTest. Only `QuestKeeperUITests` uses XCTest.
- **Strings:** every user-facing string is a catalog key with Korean as `defaultValue` and English as a peer locale. Never hardcode a literal at a call site. Keys are lowerCamelCase dot-separated segments.
- **Voice:** quest-flavored, plain, shame-free, in both locales. Forbidden in English too: `You failed`, `Graves are piling up`, `You missed it again`.
- **Non-localizable display text must use `Text(verbatim:)`** or be passed as a `String` variable, or opening the project in Xcode re-extracts it into the catalog.
- Build/test destination: `-destination 'platform=iOS Simulator,id=<UDID>' -parallel-testing-enabled NO`. Confirm the UDID with `xcrun simctl list devices available` before the first run; `iPhone 17e` was `31D132A7-FA6F-43BE-A7E3-A313FE4C407B` on 2026-08-10. Prefer an already-booted simulator — one heavy job at a time on this machine.
- Report test counts from the `.xcresult` via `xcrun xcresulttool get test-results summary`, never by grepping the log.

---

### Task 1: Derive escalations while away

**Files:**

- Modify: `QuestKeeper/Derivation/HeroDerivation.swift`
- Test: `QuestKeeperTests/DerivationTests.swift`

**Interfaces:**

- Consumes: `QuestSnapshot.mobLevel(at:)` and `QuestSnapshot.outcome(at:)`, both existing pure functions.
- Produces: `HeroState.escalationsWhileAway: [UUID]`, populated by `HeroDerivation.state(quests:now:lastOpened:calendar:)` whose signature does not change.

- [ ] **Step 1: Write the failing tests**

Append to `struct DerivationTests` in `QuestKeeperTests/DerivationTests.swift`. The existing `snapshot(id:deadlineOffset:completedOffset:importance:)` helper and the `now` / `day` properties are already in that struct — reuse them, do not redeclare.

`GameBalance.urgencyHorizon` is 7 days, so a `.high` quest 6 days out sits at a lower mob level than the same quest 1 hour out. That difference across the two instants is what the field detects.

```swift
    // MARK: - escalations while away

    @Test("a pending quest whose mob level rose since lastOpened is collected")
    func escalationCollected() {
        let questID = UUID()
        let quests = [snapshot(id: questID, deadlineOffset: 3_600, importance: .high)]
        let lastOpened = now.addingTimeInterval(-6 * day)
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        #expect(state.escalationsWhileAway == [questID])
    }

    @Test("a level that did not move is not an escalation")
    func steadyLevelIgnored() {
        let quests = [snapshot(deadlineOffset: 3_600, importance: .high)]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: now.addingTimeInterval(-60))
        #expect(state.escalationsWhileAway.isEmpty)
    }

    @Test("lastOpened equal to now yields no escalations")
    func noWindowNoEscalations() {
        let quests = [snapshot(deadlineOffset: 3_600, importance: .high)]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: now)
        #expect(state.escalationsWhileAway.isEmpty)
    }

    @Test("completed quests and graves never escalate")
    func resolvedQuestsExcluded() {
        let quests = [
            snapshot(deadlineOffset: -day, importance: .high),                          // grave
            snapshot(deadlineOffset: day, completedOffset: -60, importance: .high),     // victory
        ]
        let state = HeroDerivation.state(quests: quests, now: now, lastOpened: now.addingTimeInterval(-6 * day))
        #expect(state.escalationsWhileAway.isEmpty)
    }

    @Test("escalations are deterministic in the inputs")
    func escalationDeterminism() {
        let quests = [snapshot(deadlineOffset: 3_600, importance: .high)]
        let lastOpened = now.addingTimeInterval(-6 * day)
        let a = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        let b = HeroDerivation.state(quests: quests, now: now, lastOpened: lastOpened)
        #expect(a.escalationsWhileAway == b.escalationsWhileAway)
    }
```

- [ ] **Step 2: Run the tests and verify they fail**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/DerivationTests 2>&1 | tail -20
```

Expected: compile error — `value of type 'HeroState' has no member 'escalationsWhileAway'`.

A compile error is a valid failure here. Do not proceed until you have seen it; a pass at this step means the tests are not exercising anything.

- [ ] **Step 3: Add the field and its derivation**

In `QuestKeeper/Derivation/HeroDerivation.swift`, add the stored property to `HeroState` after `deathsWhileAway`:

```swift
    /// Pending quests whose `mobLevel` rose between `lastOpened` and `now` —
    /// the monster grew while the app was closed. Transient replay input, like `deathsWhileAway`.
    let escalationsWhileAway: [UUID]
```

In `HeroDerivation.state(...)`, add the computation next to `deathsWhileAway` and pass it to the initializer:

```swift
        let escalationsWhileAway = quests
            .filter { $0.outcome(at: now) == .pending }
            .filter { $0.mobLevel(at: lastOpened) < $0.mobLevel(at: now) }
            .map(\.id)

        return HeroState(
            totalVictories: totalVictories,
            dailyGraves: dailyGraves,
            deathsWhileAway: deathsWhileAway,
            escalationsWhileAway: escalationsWhileAway
        )
```

`HeroState` has no explicit initializer, so the memberwise one gains the parameter automatically. Every existing construction site is the one above plus test fixtures; fix whatever the compiler reports.

- [ ] **Step 4: Run the tests and verify they pass**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests 2>&1 | tail -20
```

Expected: the whole unit suite passes. Run the full `QuestKeeperTests` target, not just `DerivationTests` — adding a memberwise parameter can break other construction sites.

- [ ] **Step 5: Run the model guard**

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
```

Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add QuestKeeper/Derivation/HeroDerivation.swift QuestKeeperTests/DerivationTests.swift
git commit -m "feat(derivation): collect quests whose mob level rose while away"
```

---

### Task 2: Carry escalations through the activation replay

**Files:**

- Modify: `QuestKeeper/Actions/Activation.swift`
- Test: `QuestKeeperTests/QuestActionsTests.swift` — activation reconstruction is already tested there (its header names it, and `reconstructOnActivation` appears at lines 117, 122, 140). Append to `struct QuestActionsTests`; do not create a new file. It is `@MainActor` and already declares `let now = Date(timeIntervalSinceReferenceDate: 700_000_000)`, so reuse that property instead of redeclaring it.

**Interfaces:**

- Consumes: `HeroState.escalationsWhileAway` from Task 1.
- Produces: `reconstructOnActivation(quests:now:previousLastOpened:) -> (deaths: [UUID], escalations: [UUID], newLastOpened: Date)` and `ActivationReplayResult.escalations: [UUID]`.

- [ ] **Step 1: Write the failing test**

```swift
    @Test("the replay reports quests whose monster grew while away")
    func replayReportsEscalations() {
        let questID = UUID()
        let quests = [
            QuestSnapshot(
                id: questID,
                deadline: now.addingTimeInterval(3_600),
                completedAt: nil,
                importance: .high
            )
        ]
        let replay = reconstructOnActivation(
            quests: quests,
            now: now,
            previousLastOpened: now.addingTimeInterval(-6 * 24 * 60 * 60)
        )
        #expect(replay.escalations == [questID])
        #expect(replay.newLastOpened == now)
    }

    @Test("a first launch reports no escalations")
    func firstLaunchHasNoEscalations() {
        let quests = [
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(3_600),
                completedAt: nil,
                importance: .high
            )
        ]
        let replay = reconstructOnActivation(quests: quests, now: now, previousLastOpened: nil)
        #expect(replay.escalations.isEmpty)
    }
```

The second test pins the existing `previousLastOpened ?? now` fallback: on a first launch the window is empty, so nothing is marked.

- [ ] **Step 2: Run the test and verify it fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestActionsTests 2>&1 | tail -20
```

Expected: compile error — the returned tuple has no `escalations` member.

- [ ] **Step 3: Widen the return tuple and the replay result**

In `QuestKeeper/Actions/Activation.swift`, change `reconstructOnActivation` to return the escalations alongside the deaths:

```swift
nonisolated func reconstructOnActivation(
    quests: [QuestSnapshot],
    now: Date,
    previousLastOpened: Date?
) -> (deaths: [UUID], escalations: [UUID], newLastOpened: Date) {
    let previous = previousLastOpened ?? now
    let state = HeroDerivation.state(quests: quests, now: now, lastOpened: previous)
    return (state.deathsWhileAway, state.escalationsWhileAway, now)
}
```

Add the field to `ActivationReplayResult`:

```swift
nonisolated struct ActivationReplayResult: Equatable, Identifiable {
    let id: UUID
    let deaths: [UUID]
    let escalations: [UUID]
    let recoveryOffer: RecoveryActivationOffer?
}
```

In `makeActivationReplay`, destructure the wider tuple and pass `escalations` to **both** `ActivationReplayResult` construction sites (there is an early-return one in the `guard let dailyFocusSelections else` branch and the final one). `RecoveryState.offer` keeps taking `deathsWhileAway: deaths` unchanged — escalations are not a recovery signal.

- [ ] **Step 4: Run the tests and verify they pass**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests 2>&1 | tail -20
```

Expected: the whole unit suite passes.

- [ ] **Step 5: Commit**

```bash
git add QuestKeeper/Actions/Activation.swift QuestKeeperTests/QuestActionsTests.swift
git commit -m "feat(activation): carry mob-level escalations through the replay"
```

---

### Task 3: Thread the escalation set down to the row

**Files:**

- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`

**Interfaces:**

- Consumes: `ActivationReplayResult.escalations` from Task 2.
- Produces: `QuestRow.hasEscalated: Bool` (defaulting to `false` in the memberwise initializer), reachable from `HomeDungeonBoardView(escalatedQuestIDs:)` and `QuestListSections(escalatedQuestIDs:)`, both `Set<UUID>`.

This task adds no visible pill — Task 4 does. It ends with the value in place and the app building unchanged, which is why it carries no new test of its own beyond the suite staying green.

- [ ] **Step 1: Hold the set in `ContentView`**

Add the state next to `pendingDeaths` (`QuestKeeper/ContentView.swift:18`):

```swift
    /// Transient: quests whose monster grew while the app was closed. Replaced on the next activation.
    @State private var escalatedQuestIDs: Set<UUID> = []
```

In `applyActivationReplay()`, assign it **before** the existing early return, because that guard fires whenever nothing died and would otherwise skip escalations entirely:

```swift
    private func applyActivationReplay() {
        escalatedQuestIDs = Set(activationReplay?.escalations ?? [])
        let deaths = activationReplay?.deaths ?? []
        guard !deaths.isEmpty else { return }
        // ...unchanged mourning logic...
    }
```

Do **not** add a `mourningTask`-style timer for `escalatedQuestIDs`. `pendingDeaths` is cleared after `GameBalance.mourningDuration` because it drives a one-shot animation; the escalation marker is information and has to survive until the next activation replaces it.

- [ ] **Step 2: Pass it to the board**

In the `HomeDungeonBoardView(...)` call in `ContentView.body`, add the argument directly after `newlyMissedQuestIDs:`:

```swift
                    escalatedQuestIDs: escalatedQuestIDs,
```

- [ ] **Step 3: Accept and forward it in `HomeDungeonBoardView`**

Add the stored property immediately after `newlyMissedQuestIDs`:

```swift
    let escalatedQuestIDs: Set<UUID>
```

and forward it in the `QuestListSections(...)` call, again right after `newlyMissedQuestIDs:`:

```swift
                            escalatedQuestIDs: escalatedQuestIDs,
```

- [ ] **Step 4: Accept it in `QuestListSections` and hand it to the row**

Add the stored property after `newlyMissedQuestIDs`:

```swift
    let escalatedQuestIDs: Set<UUID>
```

`QuestRow` is constructed in three places in this file. Pass `hasEscalated:` in each:

- in `swipeableRow(_:)`, inside the `SwipeableQuestRow(...)` call, add `hasEscalated: escalatedQuestIDs.contains(quest.id),` after `showsGuidedCompletion:`, then add the matching stored property `let hasEscalated: Bool` to `SwipeableQuestRow` (after `showsGuidedCompletion`) and forward it into its own `QuestRow(...)` call as `hasEscalated: hasEscalated,`;
- in `dailyFocusSections(questIDs:)`, the completed branch builds `QuestRow(quest:now:heroAppearance:isCompleted:)` — leave it alone. A completed row renders no monster, so it never escalates.

- [ ] **Step 5: Accept it in `QuestRow`**

Add the stored property and initializer parameter, defaulted so existing call sites and previews keep compiling:

```swift
    let hasEscalated: Bool
```

In `init`, add `hasEscalated: Bool = false,` after `guidanceText:` and assign `self.hasEscalated = hasEscalated`.

- [ ] **Step 6: Build and run the suite**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: builds with no new warnings and the whole suite passes, unit and UI.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift \
        QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift
git commit -m "feat(dungeon): thread the escalation set down to the quest row"
```

---

### Task 4: Render the escalation pill

**Files:**

- Modify: `QuestKeeper/Views/QuestRow.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/AppStringsTests.swift`

**Interfaces:**

- Consumes: `QuestRow.hasEscalated` from Task 3.
- Produces: `AppStrings.questEscalatedMarker`, a `LocalizedStringResource` for key `quest.escalated.marker`.

- [ ] **Step 1: Add the catalog entry**

Add to `QuestKeeper/Localizable.xcstrings`, in the existing alphabetical position among the `quest.*` keys, matching Xcode's `"key" : value` spacing exactly (the file is excluded from prettier so Xcode owns the format):

```json
    "quest.escalated.marker" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Stronger — deadline is closer"
          }
        },
        "ko" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "마감이 다가와 세졌어요"
          }
        }
      }
    },
```

- [ ] **Step 2: Add the string constant**

In `QuestKeeper/Views/AppStrings.swift`, inside the `nonisolated extension AppStrings` block that already holds the `quest.*` keys (the one declaring `questActionComplete`), add:

```swift
    static let questEscalatedMarker = LocalizedStringResource(
        "quest.escalated.marker",
        defaultValue: "마감이 다가와 세졌어요"
    )
```

- [ ] **Step 3: Write the failing string test**

Append to `struct AppStringsTests` in `QuestKeeperTests/AppStringsTests.swift`. The `ko` and `en` locale properties already exist in that struct.

```swift
    @Test("quest.escalated.marker names the cause in both locales")
    func escalatedMarkerLocalizes() {
        #expect(AppStrings.resolve(AppStrings.questEscalatedMarker, locale: ko) == "마감이 다가와 세졌어요")
        #expect(AppStrings.resolve(AppStrings.questEscalatedMarker, locale: en) == "Stronger — deadline is closer")
    }
```

The English literal uses an em dash (U+2014), not a hyphen. Copy it rather than retyping.

- [ ] **Step 4: Run the test and verify it fails, then passes**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/AppStringsTests 2>&1 | tail -20
```

If Steps 1 and 2 are already done, this passes immediately. To confirm the test is not vacuous, temporarily change the expected English literal to `"wrong"`, re-run, see it fail, then restore it.

- [ ] **Step 5: Render the pill**

In `QuestRow.swift`, add the view below `ImportancePip`:

```swift
private struct EscalationPill: View {
    let tint: Color

    var body: some View {
        Text(AppStrings.questEscalatedMarker)
            .font(.caption2.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 2))
            .foregroundStyle(tint)
    }
}
```

In `QuestRow.body`, inside the trailing `VStack(alignment: .trailing, spacing: 8)` that holds `MobLevelBadge` and `MonsterGlyph`, insert the pill above the badge, in the `else` branch that renders a pending row:

```swift
                        } else {
                            if hasEscalated {
                                EscalationPill(tint: tone.tint)
                            }
                            MobLevelBadge(level: level)
                        }
```

`minimumScaleFactor` matters: the trailing column is `.frame(width: 100)` and the English string is longer than the Korean one.

- [ ] **Step 6: Run the localization gate and the suite**

```bash
bash scripts/test-localization.sh
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: `localization catalog tests passed`, and the whole suite green.

- [ ] **Step 7: Commit**

```bash
git add QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/AppStrings.swift \
        QuestKeeper/Localizable.xcstrings QuestKeeperTests/AppStringsTests.swift
git commit -m "feat(dungeon): mark rows whose monster grew while away"
```

---

### Task 5: Explanation sheet

**Files:**

- Create: `QuestKeeper/Views/MonsterExplanationSheet.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperTests/MonsterExplanationTests.swift`

**Interfaces:**

- Consumes: `MonsterArtworkSelection.family(forMobLevel:)`, `MonsterArtworkSelection.monster(forMobLevel:questID:)`, `MonsterKind.localizedName(locale:)`, `GameBalance.maxMobLevel`, `Importance`.
- Produces: `MonsterExplanation.tiers(maxMobLevel:)` returning `[MonsterExplanationTier]`, and the `MonsterExplanationSheet(quest:now:)` view presented in Task 6.

- [ ] **Step 1: Write the failing test for the tier table**

Create `QuestKeeperTests/MonsterExplanationTests.swift`:

```swift
//
//  MonsterExplanationTests.swift
//  QuestKeeperTests
//
//  Task 5 (AND-114) — the sheet's tier table is derived from the same mapping the
//  renderer uses, so tuning GameBalance cannot desync the explanation from reality.
//

import Testing
import Foundation
@testable import QuestKeeper

struct MonsterExplanationTests {
    @Test("tiers cover every level from 0 through maxMobLevel exactly once")
    func tiersCoverEveryLevel() {
        let tiers = MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel)
        let covered = tiers.flatMap { Array($0.levels) }
        #expect(covered == Array(0...GameBalance.maxMobLevel))
    }

    @Test("each tier lists the kinds the selector can actually return for its levels")
    func tiersMatchTheSelector() {
        for tier in MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel) {
            for level in tier.levels {
                #expect(MonsterArtworkSelection.family(forMobLevel: level) == tier.family)
            }
        }
    }
}
```

- [ ] **Step 2: Run and verify it fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/MonsterExplanationTests 2>&1 | tail -20
```

Expected: compile error — `cannot find 'MonsterExplanation' in scope`.

- [ ] **Step 3: Derive the tier table**

Create `QuestKeeper/Views/MonsterExplanationSheet.swift` starting with the pure part:

```swift
import SwiftUI

nonisolated struct MonsterExplanationTier: Equatable, Identifiable {
    let family: MonsterFamily
    let levels: ClosedRange<Int>
    let kinds: [MonsterKind]

    var id: Int { levels.lowerBound }
}

/// The tier table is read back out of the same mapping the row renderer uses, so a
/// GameBalance change cannot leave the explanation describing a rule that no longer holds.
nonisolated enum MonsterExplanation {
    static func tiers(maxMobLevel: Int) -> [MonsterExplanationTier] {
        var tiers: [MonsterExplanationTier] = []
        for level in 0...maxMobLevel {
            let family = MonsterArtworkSelection.family(forMobLevel: level)
            if let last = tiers.last, last.family == family {
                tiers[tiers.count - 1] = MonsterExplanationTier(
                    family: family,
                    levels: last.levels.lowerBound...level,
                    kinds: last.kinds
                )
            } else {
                tiers.append(MonsterExplanationTier(
                    family: family,
                    levels: level...level,
                    kinds: kinds(for: family)
                ))
            }
        }
        return tiers
    }

    /// Mirrors the variant lists in `MonsterArtworkSelection.monster(forMobLevel:questID:)`.
    static func kinds(for family: MonsterFamily) -> [MonsterKind] {
        switch family {
        case .low: [.slime, .bat, .mushroom]
        case .medium: [.skeleton, .orc, .mimic]
        case .high: [.dragon, .golem, .lich]
        }
    }
}
```

- [ ] **Step 4: Run and verify it passes**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/MonsterExplanationTests 2>&1 | tail -20
```

Expected: both tests pass.

- [ ] **Step 5: Add the sheet's catalog entries**

Add these to `QuestKeeper/Localizable.xcstrings`, each in its alphabetical position, in the same `"key" : value` style as Step 1 of Task 4:

| Key                                     | ko                                                                                                                                | en                                                                                                                                                   |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `monster.explanation.navigationTitle`   | 이 몬스터는 왜 이 몬스터인가요                                                                                                    | Why this monster                                                                                                                                     |
| `monster.explanation.importanceCaption` | 직접 정한 값                                                                                                                      | You chose this                                                                                                                                       |
| `monster.explanation.urgencyCaption`    | 시간이 정함                                                                                                                       | Time decides this                                                                                                                                    |
| `monster.explanation.rulesTitle`        | 몬스터는 이렇게 정해집니다                                                                                                        | How monsters are chosen                                                                                                                              |
| `monster.explanation.rulesBody`         | 중요도는 퀘스트를 만들 때 정하고, 마감까지 남은 시간은 계속 움직입니다. 그래서 같은 퀘스트라도 마감이 다가오면 몬스터가 바뀝니다. | You set importance when you create a quest, and the time left keeps moving. So the same quest meets a different monster as its deadline gets closer. |
| `monster.explanation.doneAction`        | 완료                                                                                                                              | Done                                                                                                                                                 |

Add the matching constants to the `nonisolated extension AppStrings` block in `QuestKeeper/Views/AppStrings.swift`, one `static let` per key, named `monsterExplanationNavigationTitle`, `monsterExplanationImportanceCaption`, `monsterExplanationUrgencyCaption`, `monsterExplanationRulesTitle`, `monsterExplanationRulesBody`, `monsterExplanationDoneAction`, each with the Korean value as `defaultValue`.

Importance names already exist — reuse `AppStrings.questEditorImportanceLow` / `Medium` / `High`. Do not add new keys for them.

- [ ] **Step 6: Build the sheet view**

Append to `QuestKeeper/Views/MonsterExplanationSheet.swift`:

```swift
struct MonsterExplanationSheet: View {
    let quest: Quest
    let now: Date

    @Environment(\.dismiss) private var dismiss

    private var level: Int { quest.snapshot.mobLevel(at: now) }
    private var kind: MonsterKind {
        MonsterArtworkSelection.monster(forMobLevel: level, questID: quest.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        DungeonArtworkView(artwork: .monster(level: level, questID: quest.id), size: 56)
                        Text(verbatim: "\(importanceName)  ×  \(countdown)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DungeonPalette.ink)
                        Text(verbatim: "\(AppStrings.resolve(AppStrings.monsterExplanationImportanceCaption, locale: .current))  ·  \(AppStrings.resolve(AppStrings.monsterExplanationUrgencyCaption, locale: .current))")
                            .font(.caption)
                            .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                        Text(verbatim: "→  Lv \(level) · \(kind.localizedName())")
                            .font(.body.weight(.bold).monospacedDigit())
                            .foregroundStyle(DungeonPalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .listRowBackground(DungeonPalette.stone)

                Section(AppStrings.monsterExplanationRulesTitle) {
                    ForEach(MonsterExplanation.tiers(maxMobLevel: GameBalance.maxMobLevel)) { tier in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "Lv \(tier.levels.lowerBound)-\(tier.levels.upperBound)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(DungeonPalette.ink.opacity(0.72))
                            Text(verbatim: tier.kinds.map { $0.localizedName() }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(DungeonPalette.ink)
                        }
                    }
                    Text(AppStrings.monsterExplanationRulesBody)
                        .font(.caption)
                        .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(DungeonPalette.stone)
            }
            .formStyle(.grouped)
            .navigationTitle(AppStrings.monsterExplanationNavigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(DungeonPalette.dungeon)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.monsterExplanationDoneAction) { dismiss() }
                        .accessibilityIdentifier("monsterExplanationDoneButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var importanceName: String {
        switch quest.importance {
        case .low: AppStrings.resolve(AppStrings.questEditorImportanceLow, locale: .current)
        case .medium: AppStrings.resolve(AppStrings.questEditorImportanceMedium, locale: .current)
        case .high: AppStrings.resolve(AppStrings.questEditorImportanceHigh, locale: .current)
        }
    }

    private var countdown: String {
        DungeonPresentation.countdownText(deadline: quest.deadline, now: now)
    }
}
```

Every interpolated string uses `Text(verbatim:)` because the values are already-resolved strings and numbers — passing an interpolated literal to `Text` would make Xcode extract `%@ × %@` into the catalog on the next project open.

- [ ] **Step 7: Run the gates**

```bash
bash scripts/test-localization.sh
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO 2>&1 | tail -20
```

Expected: both green, no new warnings.

- [ ] **Step 8: Commit**

```bash
git add QuestKeeper/Views/MonsterExplanationSheet.swift QuestKeeper/Views/AppStrings.swift \
        QuestKeeper/Localizable.xcstrings QuestKeeperTests/MonsterExplanationTests.swift
git commit -m "feat(dungeon): add the monster explanation sheet"
```

---

### Task 6: Open the sheet from the monster, without breaking swipe

**Files:**

- Modify: `QuestKeeper/Views/QuestRow.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Test: `QuestKeeperUITests/MonsterExplanationUITests.swift`

**Interfaces:**

- Consumes: `MonsterExplanationSheet(quest:now:)` from Task 5.
- Produces: `QuestRow.onExplainMonster: (() -> Void)?`, defaulting to `nil`.

**This is the task that can regress existing behavior.** The row already binds `onTapGesture` to open the editor and a `simultaneousGesture(DragGesture)` for swipe-to-reveal. The UI test asserting swipe still works is the deliverable, not a formality.

- [ ] **Step 1: Write the failing UI test**

Create `QuestKeeperUITests/MonsterExplanationUITests.swift`:

```swift
import XCTest

final class MonsterExplanationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingTheMonsterOpensTheExplanation() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["questRowTitle"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["monsterExplainButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["monsterExplanationDoneButton"].waitForExistence(timeout: 8))
    }

    /// The explain button sits inside a row that already owns a tap gesture and a drag
    /// gesture. This asserts the drag survived.
    @MainActor
    func testSwipeToRevealStillWorks() throws {
        let app = launch()
        let row = app.staticTexts["questRowTitle"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.swipeRight()
        XCTAssertTrue(app.buttons["완료"].firstMatch.waitForExistence(timeout: 4))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += uiTestKoreanLocaleArguments
        app.launchArguments += [
            "-uiTestingInMemoryStore",
            "-onboardingVariant", "control",
            "-storeScreenshotFixture",
        ]
        app.launch()
        return app
    }
}
```

This suite is Korean-pinned like the rest of `QuestKeeperUITests`, so the `완료` literal is correct here; only `StoreScreenshotUITests` runs unpinned.

- [ ] **Step 2: Run and verify both fail**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests 2>&1 | tail -20
```

Expected: the first fails because `monsterExplainButton` does not exist. If the second one **passes** already, good — it is the regression baseline; record that it passed before the change.

- [ ] **Step 3: Add the accessibility label key**

The button wraps a sprite with no text, so it needs an accessibility label the way `HeroHeader`'s appearance button does. Add to the catalog:

| Key                                       | ko                          | en                              |
| ----------------------------------------- | --------------------------- | ------------------------------- |
| `monster.explanation.buttonAccessibility` | 몬스터가 정해지는 방식 보기 | See how this monster was chosen |

and the matching `AppStrings.monsterExplanationButtonAccessibility` constant.

- [ ] **Step 4: Make the glyph a button**

In `QuestRow.swift`, add the callback property and initializer parameter:

```swift
    let onExplainMonster: (() -> Void)?
```

with `onExplainMonster: (() -> Void)? = nil,` last in `init` and `self.onExplainMonster = onExplainMonster`.

Wrap the `MonsterGlyph` in the pending branch. The glyph is 34pt, below the 44pt minimum, so it uses the same inner-padding/negative-outer-padding trick as `HeroHeader`:

```swift
                        if let onExplainMonster {
                            Button(action: onExplainMonster) {
                                MonsterGlyph(level: level, questID: quest.id)
                                    .padding(5)
                            }
                            .contentShape(Rectangle())
                            .padding(-5)
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                AppStrings.resolve(AppStrings.monsterExplanationButtonAccessibility, locale: .current)
                            )
                            .accessibilityIdentifier("monsterExplainButton")
                        } else {
                            MonsterGlyph(level: level, questID: quest.id)
                        }
```

5pt of padding takes 34pt to 44pt. Leave the `QuestBattleScene` branch untouched — there is no monster to explain mid-battle.

- [ ] **Step 5: Present the sheet from `QuestListSections`**

In `SwipeableQuestRow`, add the presentation state and pass the callback into its `QuestRow(...)`:

```swift
    @State private var explainedQuest: Quest?
```

```swift
                onExplainMonster: { explainedQuest = quest }
```

and attach the sheet to the same view the row is in:

```swift
        .sheet(item: $explainedQuest) { quest in
            MonsterExplanationSheet(quest: quest, now: now)
        }
```

`Quest` is a SwiftData `@Model`, which is already `Identifiable`, so `sheet(item:)` works without a wrapper.

- [ ] **Step 6: Run the UI tests and verify both pass**

```bash
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperUITests 2>&1 | tail -20
```

Expected: the new suite passes **and** every pre-existing UI test still passes — `QuestKeeperUITests` exercises row taps and swipes elsewhere, and those are the real regression detectors.

If `testSwipeToRevealStillWorks` now fails, the `Button` is swallowing the drag. Do not ship a workaround that disables the button; the fallback is to move the explain entry point off the row (for example onto the `Lv N` badge in a non-draggable region) and re-run. Report the finding either way.

- [ ] **Step 7: Run the full suite and the gates**

```bash
bash scripts/test-localization.sh
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -parallel-testing-enabled NO 2>&1 | tail -20
trunk fmt && trunk check
```

- [ ] **Step 8: Commit**

```bash
git add QuestKeeper/Views/QuestRow.swift QuestKeeper/Views/QuestListSections.swift \
        QuestKeeper/Views/AppStrings.swift QuestKeeper/Localizable.xcstrings \
        QuestKeeperUITests/MonsterExplanationUITests.swift
git commit -m "feat(dungeon): open the monster explanation from the row sprite"
```

---

### Task 7: Read both locales, then close out

**Files:**

- Modify: `QuestKeeperUITests/StoreScreenshotUITests.swift` (only if the new surfaces should appear in store screenshots — decide in Step 2)
- Modify: `fastlane/screenshots/generated/**` (regenerated artifacts)

**Interfaces:**

- Consumes: everything above.
- Produces: nothing other tasks depend on. This is the layout gate the automated checks cannot provide.

- [ ] **Step 1: Regenerate both locales' screenshots**

```bash
bundle exec fastlane ios screenshots
```

Expected: `💚 💚`, then eight processed and validated files per locale.

Monster sprites key on a per-launch UUID, so every PNG will differ from the committed one even where nothing changed. That is expected.

- [ ] **Step 2: Read every English screenshot, not just the changed ones**

Open each file in `fastlane/screenshots/generated/en-US/` and look at it. Specifically check:

- the escalation pill is not clipped in the 100pt trailing column — English is longer than Korean and `minimumScaleFactor(0.75)` is the only thing protecting it;
- the sheet's navigation title is not truncated the way `Edit key…` was in PR #32 — the Done button is short, so this should hold, but confirm rather than assume.

No gate reads layout. This step is the gate.

Decide here whether to add a ninth capture for the explanation sheet. If yes, add it to `StoreScreenshotUITests` following the existing `accessibilityIdentifier` pattern, renumber, and update the `expected_names` array in `scripts/validate-store-screenshots.sh` — the validator counts files per locale and will fail until both agree.

- [ ] **Step 3: Run every gate one final time**

```bash
bash scripts/test-localization.sh
bash scripts/validate-store-screenshots.sh
xcodebuild test -scheme QuestKeeper \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData \
  -resultBundlePath /tmp/and114.xcresult \
  -parallel-testing-enabled NO 2>&1 | tail -20
xcrun xcresulttool get test-results summary --path /tmp/and114.xcresult
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
trunk fmt && trunk check
```

Report the test count from the `xcresulttool` summary, not from the log. The baseline before this work was 269 test cases.

- [ ] **Step 4: Commit and open the PR**

```bash
git add fastlane/screenshots
git commit -m "chore(fastlane): regenerate store screenshots for the escalation marker"
git push -u origin ydm2790/and-114-monster-legibility
```

Open the PR with `Closes AND-114` on its own line in the body — Linear closes only the issues a PR names with a magic word. Then check for an automated reviewer; if none has attached within a couple of minutes, post `@codex review`, and work the findings with the `responding-to-ai-pr-review` skill.

Do not merge. The merge decision stays with the operator.
