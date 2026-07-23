# Recovery Loop Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two DEBUG-only, shame-free recovery prototypes that reuse the existing activation replay boundary and let an eligible returning user explicitly re-enter the daily-focus loop without changing prior quest facts.

**Architecture:** Add a pure `RecoveryState` domain seam that derives a single-use activation offer and current card presentation from explicit facts. Parse the prototype variant in `QuestKeeperApp`, keep the active offer transient in `ContentView`, render one reusable card in the home board, and route successful choices through the existing `DailyFocusSelectionRecorder` and quest editor. Use DEBUG-only deterministic fixtures for UI coverage; add no recovery persistence, assignment, event, report, dependency, or project-file edit.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XCTest UI testing, existing Quest Keeper pixel design system, Xcode synchronized file groups.

## Global Constraints

- Work in the current directory on `feature/and-36-recovery-loop`; do not create another worktree.
- Preserve the author-unknown `QuestKeeper.xcodeproj/xcshareddata/xcschemes/QuestKeeper.xcscheme` modification and exclude it from every commit.
- Do not edit `QuestKeeper.xcodeproj/project.pbxproj`; synchronized file groups discover new Swift files automatically.
- Do not add dependencies or a SwiftData recovery model.
- Do not change existing quest deadlines, completion times, importance, titles, victories, grave derivation, retries, or historical `DailyFocusSelection` snapshots automatically.
- Keep `내일 도전하기` as the only action that explicitly moves a grave into a future active attempt.
- Preserve Korean comments and user-facing strings exactly as specified.
- Do not display missed-day counts, missed-quest counts, streak loss, accumulated failure, `실패`, `밀림`, or `복구` in the recovery card.
- Recovery remains disabled unless DEBUG execution includes both `-dailyFocusLoopEnabled` and one supported `-recoveryLoopVariant` value.
- Release builds ignore the recovery arguments.
- DEBUG prototype output is not population-level retention evidence and must not change existing report formulas.
- Run at most one Xcode build, test, or Simulator-heavy job at a time.
- Run XCTest with `-parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2`.
- Never bypass commit or push hooks.

## File Structure

- Create `QuestKeeper/Recovery/RecoveryState.swift` for variant identity, activation offer derivation, complete-local-date calculation, and current card presentation.
- Create `QuestKeeper/Views/RecoveryCardView.swift` for the shared non-modal recovery card, variant actions, and neutral stale-state alert.
- Create `QuestKeeperTests/RecoveryStateTests.swift` for pure date, eligibility, presentation, and preservation boundaries.
- Modify `QuestKeeper/QuestKeeperApp.swift` for DEBUG argument parsing, deterministic UI fixtures, and dependency injection into `ContentView`.
- Modify `QuestKeeperTests/QuestKeeperAppTests.swift` for exact argument and fixture gates.
- Modify `QuestKeeper/ContentView.swift` for activation-time offer creation, explicit focus actions, dismissal, selection origin, and guided-creation fallback.
- Modify `QuestKeeper/Views/HomeDungeonBoardView.swift` to place the recovery card above ordinary dungeon content and suppress the ordinary recommendation card while recovery is active.
- Modify `QuestKeeperUITests/QuestKeeperUITests.swift` for `singleQuest`, `chooseToday`, dismissal, fallback, stale persistence, and dormant scenarios.
- Do not modify `QuestKeeperShared/Quest.swift`, any retention report, any experiment assignment model, widget code, notification code, `project.pbxproj`, or the author-unknown scheme change.

---

### Task 1: Pure Recovery State

**Files:**

- Create: `QuestKeeper/Recovery/RecoveryState.swift`
- Create: `QuestKeeperTests/RecoveryStateTests.swift`

**Interfaces:**

- Consumes: `DailyFocusPresentationState`, `DailyFocusState.rankedPendingQuestIDs(quests:now:)`, `DailyFocusDay.key(for:calendar:)`, and `QuestSnapshot`.
- Produces: `RecoveryLoopVariant`, `RecoveryActivationOffer`, `RecoveryCardPresentation`, `RecoveryState.offer(...)`, and `RecoveryState.presentation(...)`.

- [ ] **Step 1: Write the failing pure-state tests**

Create `QuestKeeperTests/RecoveryStateTests.swift` with deterministic Seoul dates and UUIDs.

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct RecoveryStateTests {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
    private var thursday: Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 23, hour: 9
        ))!
    }

    @Test("first activation and one complete date away stay ineligible")
    func ordinaryEntryIsIneligible() {
        #expect(RecoveryState.offer(
            previousLastOpened: nil,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == nil)
        #expect(RecoveryState.offer(
            previousLastOpened: calendar.date(byAdding: .day, value: -2, to: thursday),
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == nil)
    }

    @Test("two complete local dates away create one dated offer")
    func elapsedDatesCreateOffer() {
        let monday = calendar.date(byAdding: .day, value: -3, to: thursday)!

        #expect(RecoveryState.offer(
            previousLastOpened: monday,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .singleQuest
        ) == RecoveryActivationOffer(variant: .singleQuest, localDayKey: "2026-07-23"))
    }

    @Test("two unique away-window graves qualify without the date threshold")
    func repeatedMissesCreateOffer() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: thursday)!

        #expect(RecoveryState.offer(
            previousLastOpened: yesterday,
            now: thursday,
            calendar: calendar,
            deathsWhileAway: [firstID, secondID, firstID],
            hasStoredQuests: true,
            dailyFocusPresentation: .recommended([firstID]),
            variant: .chooseToday
        ) == RecoveryActivationOffer(variant: .chooseToday, localDayKey: "2026-07-23"))
    }

    @Test("no stored quest, confirmed focus, invalid clock, and disabled variant suppress recovery")
    func existingBoundariesSuppressOffer() {
        let monday = calendar.date(byAdding: .day, value: -3, to: thursday)!
        let confirmed = DailyFocusPresentationState.confirmed(
            selectedQuestIDs: [firstID], completedQuestIDs: []
        )

        for input in [
            RecoveryOfferInput(previous: monday, hasQuests: false, focus: .recommended([firstID]), variant: .singleQuest),
            RecoveryOfferInput(previous: monday, hasQuests: true, focus: confirmed, variant: .singleQuest),
            RecoveryOfferInput(previous: thursday.addingTimeInterval(1), hasQuests: true, focus: .recommended([firstID]), variant: .singleQuest),
            RecoveryOfferInput(previous: monday, hasQuests: true, focus: .recommended([firstID]), variant: nil),
        ] {
            #expect(RecoveryState.offer(
                previousLastOpened: input.previous,
                now: thursday,
                calendar: calendar,
                deathsWhileAway: [],
                hasStoredQuests: input.hasQuests,
                dailyFocusPresentation: input.focus,
                variant: input.variant
            ) == nil)
        }
    }

    @Test("presentation uses current ranking, fallback, and activation day")
    func presentationDerivation() {
        let offer = RecoveryActivationOffer(variant: .singleQuest, localDayKey: "2026-07-23")
        let quests = [
            QuestSnapshot(id: secondID, deadline: thursday.addingTimeInterval(600), completedAt: nil, importance: .low),
            QuestSnapshot(id: firstID, deadline: thursday.addingTimeInterval(300), completedAt: nil, importance: .medium),
        ]

        #expect(RecoveryState.presentation(
            offer: offer,
            quests: quests,
            dailyFocusPresentation: .recommended([firstID, secondID]),
            now: thursday,
            calendar: calendar
        ) == .singleQuest(firstID))
        #expect(RecoveryState.presentation(
            offer: RecoveryActivationOffer(variant: .chooseToday, localDayKey: "2026-07-23"),
            quests: quests,
            dailyFocusPresentation: .recommended([firstID, secondID]),
            now: thursday,
            calendar: calendar
        ) == .chooseToday)
        #expect(RecoveryState.presentation(
            offer: offer,
            quests: [QuestSnapshot(id: firstID, deadline: thursday.addingTimeInterval(-1), completedAt: nil, importance: .medium)],
            dailyFocusPresentation: .empty,
            now: thursday,
            calendar: calendar
        ) == .createQuest)
    }
}

private struct RecoveryOfferInput {
    let previous: Date?
    let hasQuests: Bool
    let focus: DailyFocusPresentationState
    let variant: RecoveryLoopVariant?
}
```

- [ ] **Step 2: Run the tests to verify they fail for missing recovery types**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RecoveryStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because `RecoveryState`, `RecoveryLoopVariant`, `RecoveryActivationOffer`, and `RecoveryCardPresentation` do not exist.

- [ ] **Step 3: Implement the minimal pure recovery domain**

Create `QuestKeeper/Recovery/RecoveryState.swift`.

```swift
import Foundation

nonisolated enum RecoveryLoopVariant: String, Equatable, Sendable {
    case singleQuest
    case chooseToday
}

nonisolated struct RecoveryActivationOffer: Equatable, Sendable {
    let variant: RecoveryLoopVariant
    let localDayKey: String
}

nonisolated enum RecoveryCardPresentation: Equatable, Sendable {
    case singleQuest(UUID)
    case chooseToday
    case createQuest
}

nonisolated enum RecoveryState {
    static func offer(
        previousLastOpened: Date?,
        now: Date,
        calendar: Calendar,
        deathsWhileAway: [UUID],
        hasStoredQuests: Bool,
        dailyFocusPresentation: DailyFocusPresentationState,
        variant: RecoveryLoopVariant?
    ) -> RecoveryActivationOffer? {
        guard let previousLastOpened,
              previousLastOpened <= now,
              hasStoredQuests,
              let variant else {
            return nil
        }
        guard case .confirmed = dailyFocusPresentation else {
            let previousDay = calendar.startOfDay(for: previousLastOpened)
            let currentDay = calendar.startOfDay(for: now)
            let boundaries = calendar.dateComponents(
                [.day], from: previousDay, to: currentDay
            ).day ?? 0
            let completeDatesAway = max(0, boundaries - 1)
            let uniqueDeaths = Set(deathsWhileAway).count
            guard completeDatesAway >= 2 || uniqueDeaths >= 2 else { return nil }
            return RecoveryActivationOffer(
                variant: variant,
                localDayKey: DailyFocusDay.key(for: now, calendar: calendar)
            )
        }
        return nil
    }

    static func presentation(
        offer: RecoveryActivationOffer?,
        quests: [QuestSnapshot],
        dailyFocusPresentation: DailyFocusPresentationState,
        now: Date,
        calendar: Calendar
    ) -> RecoveryCardPresentation? {
        guard let offer,
              offer.localDayKey == DailyFocusDay.key(for: now, calendar: calendar) else {
            return nil
        }
        guard case .confirmed = dailyFocusPresentation else {
            let pendingIDs = DailyFocusState.rankedPendingQuestIDs(quests: quests, now: now)
            guard let firstID = pendingIDs.first else { return .createQuest }
            switch offer.variant {
            case .singleQuest:
                return .singleQuest(firstID)
            case .chooseToday:
                return .chooseToday
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run the pure tests and the existing daily-focus state tests**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RecoveryStateTests -only-testing:QuestKeeperTests/DailyFocusStateTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS.

- [ ] **Step 5: Commit the pure domain boundary**

```bash
git add QuestKeeper/Recovery/RecoveryState.swift QuestKeeperTests/RecoveryStateTests.swift
git diff --cached --check
git commit -m "feat(recovery): derive return recovery offers"
```

### Task 2: DEBUG Gate And Deterministic Fixtures

**Files:**

- Modify: `QuestKeeper/QuestKeeperApp.swift`
- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeperTests/QuestKeeperAppTests.swift`

**Interfaces:**

- Consumes: `RecoveryLoopVariant` from Task 1 and existing `dailyFocusLoopEnabled(arguments:)`.
- Produces: `recoveryLoopVariant(arguments:dailyFocusLoopEnabled:)`, injected `ContentView.recoveryLoopVariant`, and isolated recovery UI fixtures.

- [ ] **Step 1: Write failing gate and fixture-isolation tests**

Add to `QuestKeeperTests/QuestKeeperAppTests.swift`:

```swift
@Test(
    "recovery variant requires daily focus and an exact supported value",
    arguments: [
        (["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "singleQuest"], true, RecoveryLoopVariant.singleQuest),
        (["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "chooseToday"], true, RecoveryLoopVariant.chooseToday),
        (["QuestKeeper", "-recoveryLoopVariant", "singleQuest"], false, nil),
        (["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant", "unknown"], true, nil),
        (["QuestKeeper", "-dailyFocusLoopEnabled", "-recoveryLoopVariant"], true, nil),
    ]
)
func recoveryVariantGate(
    arguments: [String],
    dailyFocusEnabled: Bool,
    expected: RecoveryLoopVariant?
) {
    #expect(recoveryLoopVariant(
        arguments: arguments,
        dailyFocusLoopEnabled: dailyFocusEnabled
    ) == expected)
}

@Test("recovery fixtures require an isolated UI test store")
func recoveryFixtureIsolation() {
    let arguments = ["QuestKeeper", "-uiTestingRecoveryFixture"]
    #expect(shouldSeedRecoveryFixture(
        usesUITestingStore: true,
        arguments: arguments
    ))
    #expect(!shouldSeedRecoveryFixture(
        usesUITestingStore: false,
        arguments: arguments
    ))
}
```

- [ ] **Step 2: Run the app tests to verify the new APIs are missing**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestKeeperAppTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because the recovery argument and fixture helpers do not exist.

- [ ] **Step 3: Add the exact DEBUG gate and inject it without activating UI**

In `QuestKeeper/QuestKeeperApp.swift`, add `private let recoveryLoopVariant: RecoveryLoopVariant?`, derive it only in DEBUG, set it to `nil` in Release, and pass it into `ContentView`.

```swift
nonisolated func recoveryLoopVariant(
    arguments: [String],
    dailyFocusLoopEnabled: Bool
) -> RecoveryLoopVariant? {
    guard dailyFocusLoopEnabled,
          let index = arguments.firstIndex(of: "-recoveryLoopVariant"),
          arguments.indices.contains(index + 1) else {
        return nil
    }
    return RecoveryLoopVariant(rawValue: arguments[index + 1])
}

nonisolated func shouldSeedRecoveryFixture(
    usesUITestingStore: Bool,
    arguments: [String]
) -> Bool {
    usesUITestingStore && arguments.contains("-uiTestingRecoveryFixture")
}
```

Add `recoveryLoopVariant: RecoveryLoopVariant? = nil` to `ContentView.init`, store it as a private immutable property, and do not derive or show a recovery offer yet.

- [ ] **Step 4: Add deterministic isolated UI fixture seeding**

Inside the existing DEBUG fixture block in `QuestKeeperApp.init`, when `shouldSeedRecoveryFixture` is true and the store is empty:

```swift
let now = Date.now
if !arguments.contains("-uiTestingRecoveryPersistenceFailure") {
    container.mainContext.insert(RetentionInstallation(
        installationID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        measurementStartedAt: now.addingTimeInterval(-4 * 86_400)
    ))
}
container.mainContext.insert(Quest(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
    title: "회복 퀘스트 1",
    deadline: now.addingTimeInterval(600),
    importance: .high
))
container.mainContext.insert(Quest(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
    title: "회복 퀘스트 2",
    deadline: now.addingTimeInterval(1_200),
    importance: .medium
))
container.mainContext.insert(Quest(
    title: "지켜낸 승리",
    deadline: now.addingTimeInterval(-86_400),
    importance: .low,
    completedAt: now.addingTimeInterval(-86_460)
))
UserDefaults.standard.set(
    now.addingTimeInterval(-3 * 86_400).timeIntervalSinceReferenceDate,
    forKey: "lastOpenedTIRD"
)
try container.mainContext.save()
```

Seed no assignment and no focus selection.
The retained installation allows the existing `DailyFocusSelectionRecorder` to persist an explicit prototype choice.
The `-uiTestingRecoveryPersistenceFailure` form intentionally omits that installation so UI error handling can be observed later.

- [ ] **Step 5: Run the app tests and build the app**

Run one command at a time:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestKeeperAppTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'generic/platform=iOS Simulator' -jobs 2
```

Expected: both commands exit 0; ordinary execution still has no recovery UI.

- [ ] **Step 6: Commit the gate and fixture seam**

```bash
git add QuestKeeper/QuestKeeperApp.swift QuestKeeper/ContentView.swift QuestKeeperTests/QuestKeeperAppTests.swift
git diff --cached --check
git commit -m "feat(recovery): gate debug recovery prototypes"
```

### Task 3: Shared Recovery Card

**Files:**

- Create: `QuestKeeper/Views/RecoveryCardView.swift`

**Interfaces:**

- Consumes: `RecoveryCardPresentation`, an optional resolved `Quest`, and four explicit callbacks.
- Produces: `RecoveryCardView` with `onConfirmSingleQuest: (UUID) -> Bool`, `onChooseToday: () -> Void`, `onCreateQuest: () -> Void`, and `onDismiss: () -> Void`.

- [ ] **Step 1: Create the card with exact copy and a recoverable stale-state alert**

Create `QuestKeeper/Views/RecoveryCardView.swift`:

```swift
import SwiftUI

struct RecoveryCardView: View {
    @State private var showingSelectionIssue = false

    let presentation: RecoveryCardPresentation
    let quest: Quest?
    let now: Date
    let onConfirmSingleQuest: (UUID) -> Bool
    let onChooseToday: () -> Void
    let onCreateQuest: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("다시 와서 반가워요")
                .font(.headline.weight(.black))
                .foregroundStyle(DungeonPalette.ink)
            Text("쉬었다 와도 괜찮아요. 오늘 할 일부터 가볍게 시작해볼까요?")
                .font(.subheadline)
                .foregroundStyle(DungeonPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            if case .singleQuest = presentation, let quest {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DungeonPalette.ink)
                    Text(DungeonPresentation.countdownText(
                        deadline: quest.deadline,
                        now: now
                    ))
                    .font(.caption)
                    .foregroundStyle(DungeonPalette.ink.opacity(0.7))
                }
            }

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.pixel)
                .frame(maxWidth: .infinity, minHeight: 44)
            Button("지금은 괜찮아요", action: onDismiss)
                .frame(maxWidth: .infinity, minHeight: 44)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DungeonPalette.ink)
        }
        .padding(16)
        .background(DungeonPalette.stone, in: RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(DungeonPalette.hero.opacity(0.55), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
        .alert("선택을 다시 확인해주세요", isPresented: $showingSelectionIssue) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("퀘스트 상태가 바뀌어 지금 선택을 저장하지 않았습니다.")
        }
    }

    private var primaryTitle: String {
        switch presentation {
        case .singleQuest:
            "이 퀘스트로 다시 시작"
        case .chooseToday:
            "오늘 다시 고르기"
        case .createQuest:
            "작은 퀘스트 만들기"
        }
    }

    private func primaryAction() {
        switch presentation {
        case .singleQuest(let questID):
            if !onConfirmSingleQuest(questID) {
                showingSelectionIssue = true
            }
        case .chooseToday:
            onChooseToday()
        case .createQuest:
            onCreateQuest()
        }
    }
}
```

- [ ] **Step 2: Build the standalone component**

Run:

```bash
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'generic/platform=iOS Simulator' -jobs 2
```

Expected: PASS; the synchronized app target compiles the new view without a project-file edit.

- [ ] **Step 3: Add stable previews and inspect accessibility sizing before integration**

Append previews that use local values and do not read process arguments:

```swift
#Preview("Single quest") {
    RecoveryCardView(
        presentation: .singleQuest(UUID()),
        quest: Quest(
            title: "천천히 다시 시작하는 아주 긴 회복 퀘스트 제목",
            deadline: Date.now.addingTimeInterval(600),
            importance: .medium
        ),
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Choose today") {
    RecoveryCardView(
        presentation: .chooseToday,
        quest: nil,
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
}

#Preview("Create quest") {
    RecoveryCardView(
        presentation: .createQuest,
        quest: nil,
        now: .now,
        onConfirmSingleQuest: { _ in true },
        onChooseToday: { },
        onCreateQuest: { },
        onDismiss: { }
    )
    .padding()
    .background(DungeonPalette.dungeon)
}
```

Inspect the `Single quest` preview and verify that both buttons remain vertically visible and that the quest title wraps at `.accessibility5`.

- [ ] **Step 4: Commit the shared card**

```bash
git add QuestKeeper/Views/RecoveryCardView.swift
git diff --cached --check
git commit -m "feat(recovery): add supportive recovery card"
```

### Task 4: Activation And Explicit Recovery Actions

**Files:**

- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeperTests/QuestActionsTests.swift`

**Interfaces:**

- Consumes: `RecoveryState.offer(...)`, `RecoveryState.presentation(...)`, injected `RecoveryLoopVariant?`, existing `recordDailyFocus`, existing `DailyFocusSelectionSheet`, and `QuestEditorDraft.guided(at:)`.
- Produces: one transient `RecoveryActivationOffer?`, explicit dismissal, single-quest confirmation, recovery-origin selection, and recovery-origin guided creation.

- [ ] **Step 1: Extend the activation replay test with the one-shot recovery boundary**

Add to `QuestKeeperTests/QuestActionsTests.swift` after the existing reconstruction test:

```swift
@Test("advanced activation clock cannot recreate the same recovery offer")
func recoveryOfferUsesPreviousActivationOnce() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let previous = calendar.date(byAdding: .day, value: -3, to: now)!
    let questID = UUID()
    let quests = [
        QuestSnapshot(
            id: questID,
            deadline: now.addingTimeInterval(600),
            completedAt: nil,
            importance: .medium
        ),
    ]
    let first = reconstructOnActivation(
        quests: quests,
        now: now,
        previousLastOpened: previous
    )
    let firstOffer = RecoveryState.offer(
        previousLastOpened: previous,
        now: now,
        calendar: calendar,
        deathsWhileAway: first.deaths,
        hasStoredQuests: true,
        dailyFocusPresentation: .recommended([questID]),
        variant: .singleQuest
    )
    let secondOffer = RecoveryState.offer(
        previousLastOpened: first.newLastOpened,
        now: now,
        calendar: calendar,
        deathsWhileAway: [],
        hasStoredQuests: true,
        dailyFocusPresentation: .recommended([questID]),
        variant: .singleQuest
    )

    #expect(firstOffer != nil)
    #expect(secondOffer == nil)
}
```

- [ ] **Step 2: Run the activation test before UI wiring**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/QuestActionsTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS, proving the existing advanced `lastOpened` boundary consumes the interval without a recovery record.

- [ ] **Step 3: Derive and store the offer before advancing `lastOpened`**

In `ContentView`, add `@State private var recoveryOffer: RecoveryActivationOffer?` and use the injected variant in `onBecameActive(now:)`.
Keep the existing death animation unchanged.

```swift
let snapshots = quests.map(\.snapshot)
let dailyFocusPresentation = DailyFocusState.make(
    enabled: dailyFocusLoopEnabled,
    quests: snapshots,
    selections: dailyFocusSelections.map(\.snapshot),
    now: now,
    calendar: .current
)
let (deaths, newLastOpened) = reconstructOnActivation(
    quests: snapshots,
    now: now,
    previousLastOpened: previous
)
recoveryOffer = RecoveryState.offer(
    previousLastOpened: previous,
    now: now,
    calendar: .current,
    deathsWhileAway: deaths,
    hasStoredQuests: !quests.isEmpty,
    dailyFocusPresentation: dailyFocusPresentation,
    variant: recoveryLoopVariant
)
lastOpenedRaw = newLastOpened.timeIntervalSinceReferenceDate
```

- [ ] **Step 4: Place the recovery card above ordinary content**

In the existing `TimelineView`, derive the card on every render only from the stored offer and current facts:

```swift
let recoveryPresentation = RecoveryState.presentation(
    offer: recoveryOffer,
    quests: snapshots,
    dailyFocusPresentation: dailyFocusPresentation,
    now: now,
    calendar: .current
)
```

Add `recoveryPresentation` and the four callbacks to `HomeDungeonBoardView`.
Render `RecoveryCardView` after the notification banner and before onboarding or daily-focus cards.
While recovery presentation is non-nil, do not render `DailyFocusRecommendationCard`; continue rendering `QuestListSections` and the rest of the board.

- [ ] **Step 5: Add explicit single-quest and choose-today actions**

Implement single-quest revalidation against the current presentation before writing:

```swift
private func confirmRecoveryQuest(_ questID: UUID) -> Bool {
    let now = Date.now
    let dailyFocusPresentation = DailyFocusState.make(
        enabled: dailyFocusLoopEnabled,
        quests: quests.map(\.snapshot),
        selections: dailyFocusSelections.map(\.snapshot),
        now: now,
        calendar: .current
    )
    guard RecoveryState.presentation(
        offer: recoveryOffer,
        quests: quests.map(\.snapshot),
        dailyFocusPresentation: dailyFocusPresentation,
        now: now,
        calendar: .current
    ) == .singleQuest(questID) else {
        return false
    }
    guard recordDailyFocus([questID], kind: .confirmation, at: now) else {
        return false
    }
    recoveryOffer = nil
    return true
}
```

Add `dismissesRecoveryOnSave: Bool` to `DailyFocusEditorRoute`.
The ordinary editor sets it to `false`; `오늘 다시 고르기` sets it to `true` and uses the current recommendation as the initial selection.
After a successful sheet save, clear `recoveryOffer` only when this flag is true.
Canceling the sheet leaves the offer intact.

- [ ] **Step 6: Add recovery-origin guided creation without auto-confirmation**

Add `case recoveryCreate(QuestEditorDraft)` to `EditorRoute`.
Use `.guided(at: .now)` when the card shows `.createQuest`.
Its `QuestEditor.onSaved` callback clears `recoveryOffer` and writes the widget snapshot, but does not call `recordDailyFocus`.
Canceling the editor leaves the offer intact because no callback fires.

- [ ] **Step 7: Run focused unit tests and build**

Run one command at a time:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RecoveryStateTests -only-testing:QuestKeeperTests/QuestActionsTests -only-testing:QuestKeeperTests/DailyFocusSelectionRecorderTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'generic/platform=iOS Simulator' -jobs 2
```

Expected: all focused tests and the app build pass.

- [ ] **Step 8: Commit the integrated recovery flow**

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeperTests/QuestActionsTests.swift
git diff --cached --check
git commit -m "feat(recovery): connect activation recovery choices"
```

### Task 5: End-To-End Boundaries And Manual Comparison

**Files:**

- Modify: `QuestKeeper/QuestKeeperApp.swift`
- Modify: `QuestKeeperTests/QuestKeeperAppTests.swift`
- Modify: `QuestKeeperUITests/QuestKeeperUITests.swift`

**Interfaces:**

- Consumes: the DEBUG fixture and launch gates from Task 2 and the integrated UI from Task 4.
- Produces: deterministic UI evidence for both variants, dismissal, no-pending fallback, persistence failure, and dormant execution.

- [ ] **Step 1: Write failing UI scenarios for both variants and dismissal**

Add these XCTest scenarios to `QuestKeeperUITests.swift` using a shared launch helper:

```swift
@MainActor
func testRecoverySingleQuestConfirmsOneFocus() throws {
    let app = recoveryApp(variant: "singleQuest")
    app.launch()

    XCTAssertTrue(app.staticTexts["다시 와서 반가워요"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].exists)
    XCTAssertFalse(app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS %@", "실패")
    ).firstMatch.exists)
    app.buttons["이 퀘스트로 다시 시작"].tap()

    XCTAssertTrue(app.staticTexts["오늘의 핵심 퀘스트"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["0/1 완료"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["승리 1"].exists)
}

@MainActor
func testRecoveryChooseTodayRequiresExplicitSelection() throws {
    let app = recoveryApp(variant: "chooseToday")
    app.launch()

    XCTAssertTrue(app.buttons["오늘 다시 고르기"].waitForExistence(timeout: 3))
    app.buttons["오늘 다시 고르기"].tap()
    XCTAssertTrue(app.buttons["오늘 이대로 시작 (2/3)"].waitForExistence(timeout: 2))
    app.buttons["오늘 이대로 시작 (2/3)"].tap()

    XCTAssertTrue(app.staticTexts["0/2 완료"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
}

@MainActor
func testRecoveryDismissalReturnsToOrdinaryBoardWithoutReplay() throws {
    let app = recoveryApp(variant: "singleQuest")
    app.launch()
    app.buttons["지금은 괜찮아요"].tap()

    XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
    XCTAssertTrue(app.staticTexts["회복 퀘스트 1"].exists)
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertFalse(app.staticTexts["다시 와서 반가워요"].exists)
}

@MainActor
private func recoveryApp(variant: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
        "-uiTestingInMemoryStore",
        "-uiTestingRecoveryFixture",
        "-dailyFocusLoopEnabled",
        "-recoveryLoopVariant", variant,
    ]
    return app
}
```

- [ ] **Step 2: Run the three UI tests and fix only branch-caused failures**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperUITests/QuestKeeperUITests/testRecoverySingleQuestConfirmsOneFocus -only-testing:QuestKeeperUITests/QuestKeeperUITests/testRecoveryChooseTodayRequiresExplicitSelection -only-testing:QuestKeeperUITests/QuestKeeperUITests/testRecoveryDismissalReturnsToOrdinaryBoardWithoutReplay -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS.
Do not replace the existing long-drag coordinate completion helpers; they avoid hidden swipe-action overlays for short quest rows.

- [ ] **Step 3: Add no-pending and persistence-failure fixture modes**

When `-uiTestingRecoveryNoPending` is present, seed the retained installation plus only a completed victory and a visible daily grave.
When `-uiTestingRecoveryPersistenceFailure` is present, seed pending quests but intentionally omit `RetentionInstallation`.
Keep both modes gated by `shouldSeedRecoveryFixture` so they cannot affect ordinary execution.

Add UI assertions:

```swift
@MainActor
func testRecoveryNoPendingUsesGuidedCreationWithoutAutoConfirmation() throws {
    let app = recoveryApp(variant: "singleQuest")
    app.launchArguments.append("-uiTestingRecoveryNoPending")
    app.launch()

    XCTAssertTrue(app.buttons["작은 퀘스트 만들기"].waitForExistence(timeout: 3))
    app.buttons["작은 퀘스트 만들기"].tap()
    XCTAssertTrue(app.navigationBars["새 퀘스트"].waitForExistence(timeout: 2))
    app.buttons["취소"].tap()
    XCTAssertTrue(app.buttons["작은 퀘스트 만들기"].waitForExistence(timeout: 2))
}

@MainActor
func testRecoveryPersistenceFailureKeepsCardAndExplainsConflict() throws {
    let app = recoveryApp(variant: "singleQuest")
    app.launchArguments.append("-uiTestingRecoveryPersistenceFailure")
    app.launch()
    app.buttons["이 퀘스트로 다시 시작"].tap()

    XCTAssertTrue(app.alerts["선택을 다시 확인해주세요"].waitForExistence(timeout: 2))
    app.alerts.buttons["확인"].tap()
    XCTAssertTrue(app.staticTexts["다시 와서 반가워요"].exists)
}
```

- [ ] **Step 4: Add an explicit dormant regression**

Launch the same fixture without `-recoveryLoopVariant`, then without `-dailyFocusLoopEnabled`, and assert that `다시 와서 반가워요`, `이 퀘스트로 다시 시작`, and `오늘 다시 고르기` do not exist while ordinary quest rows remain usable.

- [ ] **Step 5: Run the complete serial app test suite**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: exit 0 with no failed or skipped branch-required tests.

- [ ] **Step 6: Build the widget regression target**

Run:

```bash
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeperWidget -destination 'generic/platform=iOS Simulator' -jobs 2
```

Expected: exit 0; recovery work does not change widget sources or payloads.

- [ ] **Step 7: Manually compare both variants on the same Simulator fixture**

Install the latest DEBUG app once, then launch it separately with `singleQuest` and `chooseToday` fixture arguments.
For each launch, observe the real Simulator surface and capture evidence that:

- the shared supportive copy is readable;
- no missed-day, missed-quest, streak, or failure count appears;
- the dungeon and existing achievement remain visible;
- dismissal is immediate;
- `singleQuest` enters a one-item confirmed focus;
- `chooseToday` requires the existing explicit selection confirmation;
- VoiceOver reads title, description, optional quest, primary action, and dismissal in order;
- the largest accessibility Dynamic Type size wraps without horizontal scrolling;
- a stale or persistence-rejected selection shows the neutral alert and leaves a usable path.

Record the result as prototype comparison evidence only.

- [ ] **Step 8: Run final repository checks and inspect scope**

Run:

```bash
git diff --check
trunk check QuestKeeper/Recovery/RecoveryState.swift QuestKeeper/Views/RecoveryCardView.swift QuestKeeper/QuestKeeperApp.swift QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeperTests/RecoveryStateTests.swift QuestKeeperTests/QuestKeeperAppTests.swift QuestKeeperTests/QuestActionsTests.swift QuestKeeperUITests/QuestKeeperUITests.swift
git status --short
```

Expected: checks pass; only intended AND-36 paths are staged or committed, while the pre-existing scheme modification remains unstaged and untouched.

- [ ] **Step 9: Commit the end-to-end verification layer**

```bash
git add QuestKeeper/QuestKeeperApp.swift QuestKeeperTests/QuestKeeperAppTests.swift QuestKeeperUITests/QuestKeeperUITests.swift
git diff --cached --check
git commit -m "test(recovery): cover prototype return flows"
```

- [ ] **Step 10: Confirm the final branch scope**

```bash
git diff --check origin/main...HEAD
git log --oneline origin/main..HEAD
git status --short
```

Expected: the branch diff is clean, the five implementation commits are present after the design and plan commits, and only the preserved author-unknown scheme modification remains in the working tree.

## Completion Gate

Before opening a pull request, verify all of the following against the exact final commit SHA:

- both DEBUG variants are independently launchable;
- Release and ungated DEBUG behavior remain unchanged;
- a normal one-day gap is excluded;
- two complete local dates or two unique away-window graves qualify once;
- dismissal and process exit do not replay the same interval;
- existing quest facts, victories, grave derivation, retries, and prior selections remain unchanged;
- explicit single-quest and one-to-three choices use the existing focus recorder;
- no-pending creation does not auto-confirm focus;
- all serial tests, app build, widget build, Trunk checks, VoiceOver inspection, Dynamic Type inspection, and real Simulator scenarios pass;
- the author-unknown scheme modification remains outside all commits;
- no result is described as population retention evidence.
