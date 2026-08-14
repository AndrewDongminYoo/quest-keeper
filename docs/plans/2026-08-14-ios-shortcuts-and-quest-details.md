# iOS Shortcuts and Quest Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let people create a Quest from iOS Shortcuts without opening Quest Keeper, persist an optional normalized description, and open one read-only detail surface from every quest row or notification.

**Architecture:** `QuestCreationInput` is the common normalized value contract. The app editor keeps its existing `ModelContext` adapter, while the App Intent calls a `QuestStoreActor` adapter through one app-registered coordinator that always points at the app's current `ModelContainer`. A saved Quest is the success boundary; retention, notification scheduling, and widget refresh are independent follow-ups. `QuestDetailView` derives its available actions from the existing outcome rules and becomes the single destination for rows and notification taps.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, App Intents and App Shortcuts, UserNotifications, WidgetKit and App Group, Swift Testing, XCTest, String Catalogs.

Linear: [AND-124](https://linear.app/andrewdongminyoo/issue/AND-124/ios-단축어로-퀘스트-생성-및-설명-필드-추가). Recommended branch: `ydm2790/and-124-ios-shortcuts-quest-details`.

## Global Constraints

- Ship one background action only: create a Quest. Do not add an existing-Quest query, completion shortcut, `AppEntity`, App Intents extension, new dependency, or additional Siri action.
- Persist `Quest.details` as `String?`; the UI label is “설명” / “Description”. Existing rows migrate to `nil`.
- Normalize descriptions in one shared policy: normalize CRLF and lone CR to LF, trim surrounding whitespace and newlines, collapse three or more consecutive newlines to two, return `nil` for whitespace-only input, limit the normalized value to 1,000 `Character`s, and cap Unicode scalars at 4,000.
- The shortcut parameters appear in this exact order: title, details, deadline, importance. Title is required. Omitted details become `nil`, omitted deadline becomes invocation time plus one hour, and omitted importance becomes `.medium`. An explicitly supplied deadline at or before invocation time is rejected before any write.
- Set `CreateQuestIntent.supportedModes` to `.background`. Keep the intent source in the main app target only and register its coordinator through `AppDependencyManager` during `QuestKeeperApp.init()` as described by [Apple's dependency guidance](https://developer.apple.com/documentation/appintents/creating-your-first-app-intent). Do not add `allowedExecutionTargets` yet: Apple's current documentation marks it as beta, and the installed iOS 26.5 SDK fails to compile `IntentExecutionTargets`; re-run the Task 5 SDK probe and use `.main` only after the selected Xcode exposes that API.
- Never open a second `ModelContainer` for the App Group store inside the running app process. The coordinator receives the container created by `QuestKeeperApp`, and `QuestKeeperApp` updates the coordinator whenever activation swaps in a refreshed container.
- The first successful `modelContext.save()` commits only the Quest and is the creation boundary. Retention recording is a second best-effort save, while notification scheduling, widget snapshot persistence, and timeline reload are later follow-ups; none may roll back the committed Quest.
- Shortcut notification handling must read the current authorization only. It must never call `requestAuthorization`. `.allowed` schedules; `.notDetermined` and `.denied` report that permission can be enabled in the app; `.unavailable` is a partial failure.
- Keep `QuestSnapshot` and `WidgetQuestPayload` unchanged. Details do not participate in derivation, notification planning, or widget JSON.
- Every quest row tap and notification tap opens `QuestDetailView`. Pending details expose Edit, today's visible grave exposes Retry Tomorrow, and victories or older graves are read-only. Existing pending-row swipe completion and deletion remain unchanged.
- Every user-facing string is declared in `AppStrings` or directly as App Intent metadata with Korean and English catalog values. Verify rendered Korean and English; `scripts/test-localization.sh` cannot prove contextual correctness.
- Swift 6 strict concurrency stays clean. Unit tests use Swift Testing; UI tests use XCTest.
- Do not hand-edit `QuestKeeper.xcodeproj/project.pbxproj`. Its file-system-synchronized groups automatically include new Swift files under the existing app, shared, test, and UI-test directories.
- Use the currently verified booted simulator `iPhone 17 Pro Max` with UDID `24B14321-156A-4BC4-97DC-0183AD675A8D`; re-run `xcrun simctl list devices available` before the first build and replace the command's UDID if it drifted. Run one heavy mobile job at a time and always pass `-parallel-testing-enabled NO` to tests.

## Success Criteria and Verification Map

1. Optional details and legacy migration → verify: `QuestDetailsPolicyTests`, `QuestModelMigrationTests`, app build, widget build, and an install-over-existing-store smoke test.
2. Shared creation defaults and validation → verify: `QuestCreationInputTests` and `QuestEditor` UI coverage.
3. Shortcut store write and measurement source → verify: `QuestStoreActorTests`, `RetentionEventRecorderTests`, `RetentionReportTests`, `OnboardingFlowStateTests`, and `OnboardingExperimentReportTests`.
4. No-prompt notification and partial-success behavior → verify: `QuestNotificationServiceTests` and `QuestShortcutCreationCoordinatorTests`.
5. Discoverable background App Shortcut → verify: app build, extracted App Intents metadata, and Shortcuts-app manual checks.
6. Common details and routing → verify: `QuestDetailViewTests`, `NotificationRoutingTests`, and targeted UI tests.
7. Whole-feature regression → verify: all `QuestKeeperTests`, targeted `QuestKeeperUITests`, localization gate, explicit-path Trunk checks, model guard, and Korean/English simulator QA.

## File Ownership Map

### Create

- `QuestKeeperShared/QuestDetailsPolicy.swift` — description normalization and abuse bounds shared by app and shortcut surfaces.
- `QuestKeeperShared/QuestCreationInput.swift` — normalized common creation value and shortcut defaults/validation.
- `QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift` — single-container orchestration and partial-success result.
- `QuestKeeper/Intents/CreateQuestIntent.swift` — thin App Intent, AppEnum adapter, parameter summary, errors, and dialogs.
- `QuestKeeper/Intents/QuestKeeperAppShortcuts.swift` — one discoverable App Shortcut.
- `QuestKeeper/AppShortcuts.xcstrings` — Korean and English trigger phrases with the required application-name token.
- `QuestKeeper/Views/QuestDetailView.swift` — renamed and generalized `QuestResolutionView`.
- `QuestKeeperTests/QuestDetailsPolicyTests.swift` — normalization limits.
- `QuestKeeperTests/QuestCreationInputTests.swift` — defaults and pre-write validation.
- `QuestKeeperTests/QuestModelMigrationTests.swift` — automatic lightweight migration from the previous `Quest` schema.
- `QuestKeeperTests/QuestShortcutCreationCoordinatorTests.swift` — success, permission, and partial-failure boundaries.
- `QuestKeeperTests/QuestDetailViewTests.swift` — state/action matrix.
- `QuestKeeperTests/CreateQuestIntentTests.swift` — parameter adaptation and result-dialog selection.

### Move

- `QuestKeeper/Models/QuestTitlePolicy.swift` → `QuestKeeperShared/QuestTitlePolicy.swift` — make title normalization available to the shared creation contract without duplication.

### Modify

- `QuestKeeperShared/Quest.swift` — add `details` and a defaulted initializer parameter.
- `QuestKeeperShared/QuestStoreActor.swift` — add atomic Quest creation and a Sendable store result.
- `QuestKeeperShared/RetentionEvent.swift` — add `.shortcut` source.
- `QuestKeeperShared/RetentionEventRecorder.swift` — accept a source for `quest_created`, defaulting to `.app`.
- `QuestKeeperShared/RetentionReport.swift`, `QuestKeeperShared/OnboardingExperimentReport.swift`, `QuestKeeper/Onboarding/OnboardingFlowState.swift` — accept `.shortcut` only for `quest_created`; keep retry and experiment events app-only.
- `QuestKeeper/Notifications/QuestNotificationService.swift` — add a snapshot-based no-prompt sync path while preserving the current app prompt path.
- `QuestKeeper/QuestKeeperApp.swift` — register the coordinator and update its container after a warm foreground swap.
- `QuestKeeper/Views/QuestEditor.swift` — edit and save details through the shared contract.
- `QuestKeeper/Views/AppStrings.swift`, `QuestKeeper/Localizable.xcstrings` — description, detail, App Intent metadata, error, result, and shortcut-title copy.
- `QuestKeeper/ContentView.swift`, `QuestKeeper/Views/HomeDungeonBoardView.swift`, `QuestKeeper/Views/QuestListSections.swift`, `QuestKeeper/Views/QuestRow.swift` — route all row and notification taps to the common detail surface without changing swipe rails.
- `QuestKeeperTests/QuestStoreActorTests.swift`, `QuestKeeperTests/RetentionEventRecorderTests.swift`, `QuestKeeperTests/RetentionReportTests.swift`, `QuestKeeperTests/OnboardingExperimentReportTests.swift`, `QuestKeeperTests/OnboardingFlowStateTests.swift`, `QuestKeeperTests/QuestNotificationServiceTests.swift`, `QuestKeeperTests/NotificationRoutingTests.swift`, `QuestKeeperTests/QuestActionsTests.swift`, `QuestKeeperTests/AppStringsTests.swift`, `QuestKeeperTests/WidgetDungeonPayloadTests.swift`, `QuestKeeperTests/QuestKeeperAppTests.swift` — focused regressions.
- `QuestKeeperUITests/QuestKeeperUITests.swift` — create/edit/read details, state actions, and retained swipe behavior.
- `README.md`, `CLAUDE.md`, `BLUEPRINT.md` — add `details` to the documented raw-fact model and describe the new system boundary without rewriting historical plans/specs.

---

### Task 1: Add the optional details fact and prove lightweight migration

**Files:**

- Move: `QuestKeeper/Models/QuestTitlePolicy.swift` → `QuestKeeperShared/QuestTitlePolicy.swift`
- Create: `QuestKeeperShared/QuestDetailsPolicy.swift`
- Modify: `QuestKeeperShared/Quest.swift`
- Create: `QuestKeeperTests/QuestDetailsPolicyTests.swift`
- Create: `QuestKeeperTests/QuestModelMigrationTests.swift`
- Modify: `QuestKeeperTests/QuestActionsTests.swift`
- Modify: `QuestKeeperTests/WidgetDungeonPayloadTests.swift`

**Interfaces:**

- Produces: `Quest.details: String?`, `QuestDetailsPolicy.constrainedInput(_:) -> String`, and `QuestDetailsPolicy.normalized(_:) -> String?`.
- Preserves: `QuestSnapshot` and `WidgetQuestPayload` signatures remain unchanged.

- [ ] **Step 1: Preserve a real pre-change simulator row for the final install-over smoke test**

Build and run the untouched baseline, create one Quest named `AND-124 legacy sentinel`, then leave the app installed and do not erase its data.

```bash
xcodebuild build -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124-baseline
xcrun simctl install 24B14321-156A-4BC4-97DC-0183AD675A8D \
  /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124-baseline/Build/Products/Debug-iphonesimulator/QuestKeeper.app
xcrun simctl launch 24B14321-156A-4BC4-97DC-0183AD675A8D kr.donminzzi.QuestKeeper
```

Expected: the baseline app launches, the sentinel exists, and no description UI exists yet.

- [ ] **Step 2: Move the title policy into the shared source group**

```bash
git mv QuestKeeper/Models/QuestTitlePolicy.swift QuestKeeperShared/QuestTitlePolicy.swift
```

Do not change the type or its behavior. The move lets `QuestCreationInput` use the same policy from the app and shared actor targets.

- [ ] **Step 3: Write the failing description-policy tests**

Create `QuestKeeperTests/QuestDetailsPolicyTests.swift`:

```swift
import Testing
@testable import QuestKeeper

struct QuestDetailsPolicyTests {
    @Test("nil and whitespace-only details normalize to nil")
    func emptyDetailsBecomeNil() {
        #expect(QuestDetailsPolicy.normalized(nil) == nil)
        #expect(QuestDetailsPolicy.normalized(" \t\n\r ") == nil)
    }

    @Test("normalization trims edges, normalizes line endings, and keeps at most one blank line")
    func normalizesParagraphs() {
        let raw = "  First\r\n\r\n\r\nSecond\rThird  "
        #expect(QuestDetailsPolicy.normalized(raw) == "First\n\nSecond\nThird")
    }

    @Test("normalization preserves internal spaces")
    func preservesInternalSpaces() {
        #expect(QuestDetailsPolicy.normalized("one   two") == "one   two")
    }

    @Test("normalized details stop at 1000 characters")
    func boundsCharacters() {
        let raw = String(repeating: "a", count: QuestDetailsPolicy.maximumLength + 1)
        #expect(QuestDetailsPolicy.normalized(raw)?.count == QuestDetailsPolicy.maximumLength)
    }

    @Test("truncation cannot reintroduce trailing whitespace")
    func trimsAfterBounding() {
        let raw = String(repeating: "a", count: QuestDetailsPolicy.maximumLength - 1) + "  tail"
        #expect(QuestDetailsPolicy.normalized(raw)?.last == "a")
    }

    @Test("constrained input bounds abusive grapheme clusters")
    func boundsScalars() {
        let abusive = "a" + String(repeating: "\u{0301}", count: 10_000)
        #expect(QuestDetailsPolicy.constrainedInput(abusive).unicodeScalars.count <= QuestDetailsPolicy.maximumScalars)
    }
}
```

- [ ] **Step 4: Run the policy test and verify it fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestDetailsPolicyTests
```

Expected: compile failure because `QuestDetailsPolicy` does not exist.

- [ ] **Step 5: Implement the details policy**

Create `QuestKeeperShared/QuestDetailsPolicy.swift`:

```swift
import Foundation

nonisolated enum QuestDetailsPolicy {
    static let maximumLength = 1_000
    static let maximumScalars = maximumLength * 4

    static func constrainedInput(_ details: String) -> String {
        let byCharacter = String(details.prefix(maximumLength))
        guard byCharacter.unicodeScalars.count > maximumScalars else { return byCharacter }
        return String(String.UnicodeScalarView(byCharacter.unicodeScalars.prefix(maximumScalars)))
    }

    static func normalized(_ details: String?) -> String? {
        guard let details else { return nil }
        let lineNormalized = details
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmed = lineNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var collapsed = ""
        var newlineRun = 0
        for character in trimmed {
            if character == "\n" {
                newlineRun += 1
                if newlineRun <= 2 { collapsed.append(character) }
            } else {
                newlineRun = 0
                collapsed.append(character)
            }
        }
        let bounded = constrainedInput(collapsed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return bounded.isEmpty ? nil : bounded
    }
}
```

- [ ] **Step 6: Add the optional model property with a source-compatible initializer**

Change `QuestKeeperShared/Quest.swift` so `details` is stored after `title`, and put its defaulted initializer argument last to preserve every current call site:

```swift
    var id: UUID
    var title: String
    var details: String?
    var deadline: Date
    var completedAt: Date?
    var importance: Importance

    init(
        id: UUID = UUID(),
        title: String,
        deadline: Date,
        importance: Importance,
        completedAt: Date? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.deadline = deadline
        self.importance = importance
        self.completedAt = completedAt
    }
```

- [ ] **Step 7: Write the previous-schema migration test**

Create `QuestKeeperTests/QuestModelMigrationTests.swift`. The nested legacy type deliberately keeps the entity name `Quest`, which matches the production table while omitting `details`:

```swift
import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

private enum LegacyQuestSchema {
    @Model
    final class Quest {
        var id: UUID
        var title: String
        var deadline: Date
        var completedAt: Date?
        var importance: Importance

        init(id: UUID, title: String, deadline: Date, completedAt: Date?, importance: Importance) {
            self.id = id
            self.title = title
            self.deadline = deadline
            self.completedAt = completedAt
            self.importance = importance
        }
    }
}

@MainActor
struct QuestModelMigrationTests {
    @Test("the previous Quest schema opens with details nil and preserves every old fact")
    func migratesOptionalDetails() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "store.sqlite")
        let id = UUID()
        let deadline = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let completedAt = deadline.addingTimeInterval(-60)

        do {
            let legacySchema = Schema([LegacyQuestSchema.Quest.self])
            let legacyConfiguration = ModelConfiguration(schema: legacySchema, url: storeURL)
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: [legacyConfiguration]
            )
            legacyContainer.mainContext.insert(LegacyQuestSchema.Quest(
                id: id,
                title: "Legacy quest",
                deadline: deadline,
                completedAt: completedAt,
                importance: .high
            ))
            try legacyContainer.mainContext.save()
        }

        let current = try QuestModelContainer.make(
            storeURL: storeURL,
            retryKeyMigrationMarkerURL: directory.appending(path: "retry-migration-marker")
        )
        let quests = try current.mainContext.fetch(FetchDescriptor<Quest>())
        #expect(quests.count == 1)
        #expect(quests[0].id == id)
        #expect(quests[0].title == "Legacy quest")
        #expect(quests[0].details == nil)
        #expect(quests[0].deadline == deadline)
        #expect(quests[0].completedAt == completedAt)
        #expect(quests[0].importance == .high)
    }
}
```

- [ ] **Step 8: Pin non-projection and raw-fact preservation regressions**

In `QuestKeeperTests/QuestActionsTests.swift`, create a Quest with `details: "Keep me"`, call `QuestActions.retryTomorrow`, and assert `details` is unchanged. In `QuestKeeperTests/WidgetDungeonPayloadTests.swift`, create two otherwise identical Quests with different descriptions and assert their `WidgetQuestPayload` values remain equal.

```swift
    @Test("retry tomorrow preserves details")
    func retryPreservesDetails() {
        let quest = Quest(
            title: "Retry",
            deadline: now.addingTimeInterval(-60),
            importance: .medium,
            details: "Keep me"
        )
        QuestActions.retryTomorrow(quest, now: now, calendar: calendar)
        #expect(quest.details == "Keep me")
    }
```

```swift
    @Test("widget payload deliberately omits quest details")
    func widgetPayloadOmitsDetails() {
        let id = UUID()
        let first = Quest(id: id, title: "Same", deadline: now, importance: .medium, details: "One")
        let second = Quest(id: id, title: "Same", deadline: now, importance: .medium, details: "Two")
        #expect(WidgetDungeonPayload.make(from: [first]).quests == WidgetDungeonPayload.make(from: [second]).quests)
    }
```

- [ ] **Step 9: Run the focused model tests**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestDetailsPolicyTests \
  -only-testing:QuestKeeperTests/QuestModelMigrationTests \
  -only-testing:QuestKeeperTests/QuestActionsTests \
  -only-testing:QuestKeeperTests/WidgetDungeonPayloadTests
```

Expected: all selected tests pass. If the migration test reports an incompatible store, stop here and revise this plan with an explicit `VersionedSchema`/`SchemaMigrationPlan`; do not ship or improvise a migration because the approved fallback is conditional on this concrete failure.

- [ ] **Step 10: Run the stored-state guard**

```bash
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
```

Expected: no output and exit 0. `details` is a user-entered raw fact and does not match the forbidden derived-state list.

- [ ] **Step 11: Commit the model boundary**

```bash
git add QuestKeeper/Models/QuestTitlePolicy.swift QuestKeeperShared/Quest.swift QuestKeeperShared/QuestTitlePolicy.swift QuestKeeperShared/QuestDetailsPolicy.swift QuestKeeperTests/QuestDetailsPolicyTests.swift QuestKeeperTests/QuestModelMigrationTests.swift QuestKeeperTests/QuestActionsTests.swift QuestKeeperTests/WidgetDungeonPayloadTests.swift
git commit -m "feat(model): add optional quest details"
```

---

### Task 2: Add the common creation contract and app editor adapter

**Files:**

- Create: `QuestKeeperShared/QuestCreationInput.swift`
- Create: `QuestKeeperTests/QuestCreationInputTests.swift`
- Modify: `QuestKeeper/Views/QuestEditor.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Modify: `QuestKeeperTests/AppStringsTests.swift`

**Interfaces:**

- Consumes: `QuestTitlePolicy` and `QuestDetailsPolicy` from Task 1.
- Produces: `QuestCreationInput.init(title:details:deadline:importance:)`, `QuestCreationInput.shortcut(title:details:deadline:importance:now:)`, and `QuestCreationInputError`.

- [ ] **Step 1: Write the failing input-contract tests**

Create `QuestKeeperTests/QuestCreationInputTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct QuestCreationInputTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("shortcut defaults details, deadline, and importance")
    func shortcutDefaults() throws {
        let input = try QuestCreationInput.shortcut(
            title: "  Defeat\nslime  ",
            details: "   ",
            deadline: nil,
            importance: nil,
            now: now
        )
        #expect(input.title == "Defeat slime")
        #expect(input.details == nil)
        #expect(input.deadline == now.addingTimeInterval(3_600))
        #expect(input.importance == .medium)
    }

    @Test("shortcut normalizes supplied details and preserves supplied values")
    func shortcutSuppliedValues() throws {
        let deadline = now.addingTimeInterval(7_200)
        let input = try QuestCreationInput.shortcut(
            title: "Quest",
            details: " First\n\n\nSecond ",
            deadline: deadline,
            importance: .high,
            now: now
        )
        #expect(input.details == "First\n\nSecond")
        #expect(input.deadline == deadline)
        #expect(input.importance == .high)
    }

    @Test("empty title and explicit non-future deadline fail before storage")
    func invalidShortcutInput() {
        #expect(throws: QuestCreationInputError.emptyTitle) {
            try QuestCreationInput.shortcut(
                title: " \n ", details: nil, deadline: nil, importance: nil, now: now
            )
        }
        #expect(throws: QuestCreationInputError.deadlineNotInFuture) {
            try QuestCreationInput.shortcut(
                title: "Quest", details: nil, deadline: now, importance: nil, now: now
            )
        }
    }
}
```

- [ ] **Step 2: Run the contract tests and verify they fail**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestCreationInputTests
```

Expected: compile failure because `QuestCreationInput` does not exist.

- [ ] **Step 3: Implement the normalized common value**

Create `QuestKeeperShared/QuestCreationInput.swift`:

```swift
import Foundation

nonisolated enum QuestCreationInputError: Error, Equatable, Sendable {
    case emptyTitle
    case deadlineNotInFuture
}

nonisolated struct QuestCreationInput: Equatable, Sendable {
    static let defaultDeadlineOffset: TimeInterval = 60 * 60

    let title: String
    let details: String?
    let deadline: Date
    let importance: Importance

    init(title: String, details: String?, deadline: Date, importance: Importance) throws {
        let normalizedTitle = QuestTitlePolicy.normalized(title)
        guard !normalizedTitle.isEmpty else { throw QuestCreationInputError.emptyTitle }
        self.title = normalizedTitle
        self.details = QuestDetailsPolicy.normalized(details)
        self.deadline = deadline
        self.importance = importance
    }

    static func shortcut(
        title: String,
        details: String?,
        deadline: Date?,
        importance: Importance?,
        now: Date
    ) throws -> QuestCreationInput {
        let resolvedDeadline = deadline ?? now.addingTimeInterval(defaultDeadlineOffset)
        if deadline != nil, resolvedDeadline <= now {
            throw QuestCreationInputError.deadlineNotInFuture
        }
        return try QuestCreationInput(
            title: title,
            details: details,
            deadline: resolvedDeadline,
            importance: importance ?? .medium
        )
    }
}
```

- [ ] **Step 4: Add description input to the existing editor**

In `QuestKeeper/Views/QuestEditor.swift`, add `@State private var details: String`, initialize it from `quest?.details ?? ""`, put a multiline `TextField` immediately after the title, and construct `QuestCreationInput` once in `save()`:

```swift
    @State private var title: String
    @State private var details: String
    @State private var deadline: Date
    @State private var importance: Importance
```

```swift
        _title = State(initialValue: initialTitle)
        _details = State(initialValue: QuestDetailsPolicy.constrainedInput(quest?.details ?? ""))
        _deadline = State(initialValue: max(initialDeadline, now))
        _importance = State(initialValue: initialImportance)
```

```swift
                TextField(AppStrings.questEditorTitleField, text: Binding(
                    get: { title },
                    set: { title = QuestTitlePolicy.constrainedInput($0) }
                ))
                TextField(
                    AppStrings.questFieldDetails,
                    text: Binding(
                        get: { details },
                        set: { details = QuestDetailsPolicy.constrainedInput($0) }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)
                .accessibilityIdentifier("questDetailsField")
                DatePicker(AppStrings.questFieldDeadline, selection: $deadline, in: Date.now...)
```

```swift
    private func save() {
        let savedAt = Date.now
        guard let input = try? QuestCreationInput(
            title: title,
            details: details,
            deadline: deadline,
            importance: importance
        ) else { return }
        let savedQuest: Quest
        if let quest {
            quest.title = input.title
            quest.details = input.details
            quest.deadline = input.deadline
            quest.importance = input.importance
            savedQuest = quest
        } else {
            let newQuest = Quest(
                title: input.title,
                deadline: input.deadline,
                importance: input.importance,
                details: input.details
            )
            modelContext.insert(newQuest)
            _ = RetentionEventRecorder.recordQuestCreated(
                questID: newQuest.id,
                at: savedAt,
                in: modelContext
            )
            savedQuest = newQuest
        }
        onSaved(savedQuest)
        dismiss()

        Task { @MainActor in
            let authorization = await notificationService.sync(quest: savedQuest, now: .now)
            onAuthorizationChange(authorization)
        }
    }
```

- [ ] **Step 5: Add the field localization and direct locale assertions**

Add this declaration to `AppStrings` and the exact `ko`/`en` catalog values:

```swift
    static let questFieldDetails = LocalizedStringResource(
        "quest.field.details",
        defaultValue: "설명"
    )
```

```swift
    @Test("quest details field resolves in both locales")
    func questDetailsFieldLocalizes() {
        #expect(AppStrings.resolve(AppStrings.questFieldDetails, locale: ko) == "설명")
        #expect(AppStrings.resolve(AppStrings.questFieldDetails, locale: en) == "Description")
    }
```

- [ ] **Step 6: Run the contract, localization, and editor build checks**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestCreationInputTests \
  -only-testing:QuestKeeperTests/AppStringsTests
bash scripts/test-localization.sh QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings
xcodebuild build -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124
```

Expected: selected tests, localization gate, and app build pass.

- [ ] **Step 7: Commit the creation contract and app adapter**

```bash
git add QuestKeeperShared/QuestCreationInput.swift QuestKeeper/Views/QuestEditor.swift QuestKeeper/Views/AppStrings.swift QuestKeeper/Localizable.xcstrings QuestKeeperTests/QuestCreationInputTests.swift QuestKeeperTests/AppStringsTests.swift
git commit -m "feat(editor): add normalized quest descriptions"
```

---

### Task 3: Add the shortcut store adapter and preserve measurement semantics

**Files:**

- Modify: `QuestKeeperShared/QuestStoreActor.swift`
- Modify: `QuestKeeperShared/RetentionEvent.swift`
- Modify: `QuestKeeperShared/RetentionEventRecorder.swift`
- Modify: `QuestKeeperShared/RetentionReport.swift`
- Modify: `QuestKeeperShared/OnboardingExperimentReport.swift`
- Modify: `QuestKeeper/Onboarding/OnboardingFlowState.swift`
- Modify: `QuestKeeperTests/QuestStoreActorTests.swift`
- Modify: `QuestKeeperTests/RetentionEventRecorderTests.swift`
- Modify: `QuestKeeperTests/RetentionReportTests.swift`
- Modify: `QuestKeeperTests/OnboardingExperimentReportTests.swift`
- Modify: `QuestKeeperTests/OnboardingFlowStateTests.swift`

**Interfaces:**

- Consumes: `QuestCreationInput` from Task 2.
- Produces: `QuestStoreActor.create(input:id:createdAt:) async throws -> QuestStoreCreateResult` and `RetentionEventSource.shortcut`.
- Preserves: `recordQuestCreated` defaults to `.app`, so existing app creation behavior and call sites do not change.

- [ ] **Step 1: Write the failing actor creation test**

Append to `QuestKeeperTests/QuestStoreActorTests.swift`. Seed `RetentionInstallation` before invoking the actor so the test never depends on an App Group identity file:

```swift
    @Test("create saves normalized facts, a shortcut event, and a current widget payload")
    func createsQuestFromShortcut() async throws {
        let c = try container()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let installationID = UUID()
        c.mainContext.insert(RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: now
        ))
        try c.mainContext.save()
        let input = try QuestCreationInput(
            title: "Shortcut quest",
            details: "First\n\nSecond",
            deadline: now.addingTimeInterval(3_600),
            importance: .high
        )
        let questID = UUID()

        let result = try await QuestStoreActor(modelContainer: c).create(
            input: input,
            id: questID,
            createdAt: now
        )
        let payload = try await QuestStoreActor(modelContainer: c).snapshotPayload(generatedAt: now)

        let fresh = ModelContext(c)
        let quest = try fresh.fetch(
            FetchDescriptor<Quest>(predicate: #Predicate { $0.id == questID })
        ).first
        let events = try fresh.fetch(FetchDescriptor<RetentionEvent>())
        #expect(quest?.title == "Shortcut quest")
        #expect(quest?.details == "First\n\nSecond")
        #expect(quest?.deadline == input.deadline)
        #expect(quest?.importance == .high)
        #expect(result.questID == questID)
        #expect(result.retentionRecordResult == .inserted)
        #expect(payload.quests.map(\.id).contains(questID))
        #expect(events.count == 1)
        #expect(events.first?.snapshot.name == .questCreated)
        #expect(events.first?.snapshot.source == .shortcut)
    }

    @Test("retention failure after the creation boundary keeps the Quest")
    func retentionFailureDoesNotRollBackQuest() async throws {
        let schema = Schema([Quest.self])
        let c = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let result = try await QuestStoreActor(modelContainer: c).create(
            input: try QuestCreationInput(
                title: "Still created",
                details: nil,
                deadline: now.addingTimeInterval(3_600),
                importance: .medium
            ),
            createdAt: now
        )

        #expect(result.retentionRecordResult == .failed)
        #expect(try ModelContext(c).fetchCount(FetchDescriptor<Quest>()) == 1)
    }
```

The second test deliberately omits the retention models from its in-memory schema. The recorder's fetch fails deterministically after the Quest-only save, proving measurement failure cannot erase the new fact without adding a production test hook.

- [ ] **Step 2: Run the actor test and verify it fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestStoreActorTests
```

Expected: compile failure because `create` and `.shortcut` do not exist.

- [ ] **Step 3: Add the source and source-compatible recorder signature**

In `QuestKeeperShared/RetentionEvent.swift`:

```swift
nonisolated enum RetentionEventSource: String, Codable, CaseIterable, Sendable {
    case app
    case widget
    case shortcut
}
```

In `QuestKeeperShared/RetentionEventRecorder.swift`:

```swift
    static func recordQuestCreated(
        questID: UUID,
        at occurredAt: Date,
        source: RetentionEventSource = .app,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCreated,
            source: source,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: questID.uuidString,
            in: context
        )
    }
```

- [ ] **Step 4: Implement the actor-owned create transaction and Sendable result**

Add this value above `QuestStoreActor` and this method inside the actor in `QuestKeeperShared/QuestStoreActor.swift`:

```swift
nonisolated struct QuestStoreCreateResult: Equatable, Sendable {
    let questID: UUID
    let deadline: Date
    let importance: Importance
    let retentionRecordResult: RetentionRecordResult
}
```

```swift
    func create(
        input: QuestCreationInput,
        id: UUID = UUID(),
        createdAt: Date
    ) throws -> QuestStoreCreateResult {
        let quest = Quest(
            id: id,
            title: input.title,
            deadline: input.deadline,
            importance: input.importance,
            details: input.details
        )
        modelContext.insert(quest)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        var retentionResult = RetentionEventRecorder.recordQuestCreated(
            questID: id,
            at: createdAt,
            source: .shortcut,
            in: modelContext
        )
        if retentionResult == .inserted {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                retentionResult = .failed
            }
        } else if retentionResult == .failed {
            modelContext.rollback()
        }
        return QuestStoreCreateResult(
            questID: id,
            deadline: input.deadline,
            importance: input.importance,
            retentionRecordResult: retentionResult
        )
    }
```

Do not return the SwiftData `Quest` across the actor boundary. The first save contains only `Quest`; never move `recordQuestCreated` above it. A failed second retention save is converted to `.failed` after rolling back only the unsaved measurement changes. Do not fetch or save the widget snapshot inside `create`; widget work is a post-commit follow-up in Task 4 and must not turn a committed Quest into an intent failure.

- [ ] **Step 5: Teach every measurement validator the one new valid combination**

In `OnboardingFlowState.validCombination`, `RetentionReport.isValidCombination`, and `OnboardingExperimentReport.validCombination`, split the old combined creation/retry case exactly as follows:

```swift
        case .questCreated:
            return (source == .app || source == .shortcut) && event.questID != nil
        case .questRetried:
            return source == .app && event.questID != nil
```

Use the local `questID` spelling in the two report functions:

```swift
    case .questCreated:
        (source == .app || source == .shortcut) && questID != nil
    case .questRetried:
        source == .app && questID != nil
```

Do not broaden any experiment, activation, retry, or completion rule.

- [ ] **Step 6: Add recorder and report regression tests**

In `RetentionEventRecorderTests`, record one Quest creation with `source: .shortcut` and assert the persisted source. In `RetentionReportTests`, replace one baseline creation's source with `.shortcut` and assert the metrics and unsupported count match the baseline. In `OnboardingExperimentReportTests`, replace the guided-A creation source and assert the guided funnel remains the approved value with no unsupported row:

```swift
    @Test("shortcut quest creation is retained as its own valid source")
    func shortcutCreationSource() throws {
        let container = try measurementContainer()
        let context = container.mainContext
        context.insert(RetentionInstallation(installationID: installationID, measurementStartedAt: now))
        #expect(RetentionEventRecorder.recordQuestCreated(
            questID: questID,
            at: now,
            source: .shortcut,
            in: context
        ) == .inserted)
        try context.save()
        let event = try context.fetch(FetchDescriptor<RetentionEvent>()).first
        #expect(event?.snapshot.source == .shortcut)
    }
```

```swift
    @Test("shortcut creation remains valid first-value input")
    func shortcutCreationCountsAsFirstValue() {
        let creation = RetentionBaselineFixture.events[1]
        let shortcutCreation = RetentionEventSnapshot(
            id: creation.id,
            schemaVersion: creation.schemaVersion,
            nameRawValue: creation.nameRawValue,
            installationID: creation.installationID,
            occurredAt: creation.occurredAt,
            sourceRawValue: RetentionEventSource.shortcut.rawValue,
            questID: creation.questID,
            deduplicationKey: creation.deduplicationKey
        )
        let events = RetentionBaselineFixture.events.map { $0.id == creation.id ? shortcutCreation : $0 }
        let report = makeReport(events: events)
        #expect(report.firstValue == RetentionRate(achieved: 3, eligible: 4))
        #expect(report.dataQuality.unsupportedCount == 0)
    }
```

```swift
    @Test("shortcut creation is valid onboarding first value")
    func shortcutCreationCountsInOnboardingReport() {
        let original = OnboardingExperimentFixture.events[10]
        let shortcut = RetentionEventSnapshot(
            id: original.id,
            schemaVersion: original.schemaVersion,
            nameRawValue: original.nameRawValue,
            installationID: original.installationID,
            occurredAt: original.occurredAt,
            sourceRawValue: RetentionEventSource.shortcut.rawValue,
            questID: original.questID,
            deduplicationKey: original.deduplicationKey
        )
        let events = OnboardingExperimentFixture.events.map { $0.id == original.id ? shortcut : $0 }
        let report = makeReport(events: events)
        #expect(report.guided.funnel == OnboardingExperimentFixture.expectedGuidedFunnel)
        #expect(report.dataQuality.unsupportedCount == 0)
    }
```

- [ ] **Step 7: Pin live onboarding presentation behavior for shortcut creation**

Let the private `event` helper in `OnboardingFlowStateTests` accept a `source` argument defaulting to `.app`, then add:

```swift
    @Test("a shortcut-created quest advances guided onboarding")
    func shortcutCreationAdvancesGuidedFlow() {
        let shortcutCreation = event(
            id: 3,
            name: .questCreated,
            at: assignedAt.addingTimeInterval(2),
            questID: questID,
            source: .shortcut
        )
        #expect(makeState(
            events: [exposure(), creationStarted(), shortcutCreation],
            pending: [questID],
            deferred: false
        ) == .guidedCompletion(questID: questID))
    }
```

- [ ] **Step 8: Run the actor and measurement suites**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestStoreActorTests \
  -only-testing:QuestKeeperTests/RetentionEventRecorderTests \
  -only-testing:QuestKeeperTests/RetentionReportTests \
  -only-testing:QuestKeeperTests/OnboardingExperimentReportTests \
  -only-testing:QuestKeeperTests/OnboardingFlowStateTests
```

Expected: all selected suites pass, `quest_created` from `.shortcut` is accepted, and app-only event rules remain covered.

- [ ] **Step 9: Commit the shortcut store adapter**

```bash
git add QuestKeeperShared/QuestStoreActor.swift QuestKeeperShared/RetentionEvent.swift QuestKeeperShared/RetentionEventRecorder.swift QuestKeeperShared/RetentionReport.swift QuestKeeperShared/OnboardingExperimentReport.swift QuestKeeper/Onboarding/OnboardingFlowState.swift QuestKeeperTests/QuestStoreActorTests.swift QuestKeeperTests/RetentionEventRecorderTests.swift QuestKeeperTests/RetentionReportTests.swift QuestKeeperTests/OnboardingExperimentReportTests.swift QuestKeeperTests/OnboardingFlowStateTests.swift
git commit -m "feat(shortcuts): persist shortcut-created quests"
```

---

### Task 4: Orchestrate no-prompt follow-ups with the app's current container

**Files:**

- Modify: `QuestKeeper/Notifications/QuestNotificationService.swift`
- Create: `QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift`
- Modify: `QuestKeeper/QuestKeeperApp.swift`
- Modify: `QuestKeeperTests/QuestNotificationServiceTests.swift`
- Create: `QuestKeeperTests/QuestShortcutCreationCoordinatorTests.swift`
- Modify: `QuestKeeperTests/QuestKeeperAppTests.swift`

**Interfaces:**

- Consumes: `QuestStoreActor.create` and `snapshotPayload` from Task 3.
- Produces: `QuestNotificationService.syncWithoutRequestingAuthorization(snapshot:now:locale:)`, `QuestShortcutCreationCoordinator.create(input:now:locale:)`, and `QuestShortcutCreationOutcome`.
- Preserves: the existing app editor still calls `sync(quest:now:locale:)`, which may request notification permission. Only the shortcut path is current-status-only.

- [ ] **Step 1: Write failing notification tests for the no-prompt path**

In `QuestKeeperTests/QuestNotificationServiceTests.swift`, add `private enum FakeNotificationError: Error { case addFailed }`, add `var addError: Error?` to `FakeQuestNotificationCenter`, and start `add(_:)` with `if let addError { throw addError }`. Then add these cases:

```swift
    @Test("shortcut sync never requests undetermined notification permission")
    func shortcutSyncDoesNotPrompt() async {
        let center = FakeQuestNotificationCenter(status: .notDetermined)
        let service = makeService(center: center)
        let snapshot = quest(deadlineOffset: 3 * hour).snapshot

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: snapshot,
            now: now,
            locale: Locale(identifier: "ko")
        )

        #expect(authorization == .notDetermined)
        #expect(center.addedRequests.isEmpty)
        #expect(center.events.contains("requestAuthorization") == false)
    }

    @Test("shortcut sync schedules when permission already exists")
    func shortcutSyncUsesExistingPermission() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        let service = makeService(center: center)
        let snapshot = quest(deadlineOffset: 3 * hour).snapshot

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: snapshot,
            now: now
        )

        #expect(authorization == .allowed)
        #expect(center.addedRequests.count == 2)
        #expect(center.events.contains("requestAuthorization") == false)
    }

    @Test("shortcut sync reports scheduling failure as unavailable")
    func shortcutSyncReportsAddFailure() async {
        let center = FakeQuestNotificationCenter(status: .authorized)
        center.addError = FakeNotificationError.addFailed
        let service = makeService(center: center)

        let authorization = await service.syncWithoutRequestingAuthorization(
            snapshot: quest(deadlineOffset: 3 * hour).snapshot,
            now: now
        )

        #expect(authorization == .unavailable)
    }
```

Keep the existing `reconcileDoesNotPromptForPermission` regression; the new method is a per-Quest write path, while reconciliation remains whole-store activation work.

- [ ] **Step 2: Run the notification suite and verify the new tests fail**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestNotificationServiceTests
```

Expected: compile failure because `syncWithoutRequestingAuthorization` and the fake failure hook do not exist.

- [ ] **Step 3: Add one policy switch inside the existing serialized sync path**

In `QuestNotificationService`, first make the value result usable across the intent boundary with `nonisolated enum QuestNotificationAuthorization: Equatable, Sendable`. Keep `enqueue` as the only operation serializer. Add a private policy and route both public methods through the same `performSync` implementation:

```swift
    private enum AuthorizationRequestPolicy {
        case ifNeeded
        case never
    }

    @discardableResult
    func sync(quest: Quest, now: Date, locale: Locale = .current) async -> QuestNotificationAuthorization {
        await sync(
            questID: quest.id,
            snapshot: quest.snapshot,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .ifNeeded
        )
    }

    @discardableResult
    func syncWithoutRequestingAuthorization(
        snapshot: QuestSnapshot,
        now: Date,
        locale: Locale = .current
    ) async -> QuestNotificationAuthorization {
        await sync(
            questID: snapshot.id,
            snapshot: snapshot,
            now: now,
            locale: locale,
            authorizationRequestPolicy: .never
        )
    }
```

The private `sync` helper enqueues `performSync`. In `performSync`, replace the unconditional permission request with:

```swift
        let authorization = switch authorizationRequestPolicy {
        case .ifNeeded:
            await requestAuthorizationIfNeeded()
        case .never:
            await authorizationStatus()
        }
```

Preserve the current remove-before-add order and planner. Do not duplicate request construction.

- [ ] **Step 4: Write the failing coordinator boundary tests**

Create `QuestKeeperTests/QuestShortcutCreationCoordinatorTests.swift` as an `@MainActor` suite with in-memory `ModelContainer`s. Its normal `makeContainer()` helper includes `Quest`, `RetentionInstallation`, and `RetentionEvent`, inserts one `RetentionInstallation`, and saves before returning so coordinator tests never touch the real App Group identity file. Inject `scheduleNotifications` and `updateWidgetSnapshot` closures; do not use the system notification center, App Group directory, or `WidgetCenter` in unit tests.

Cover these four contracts:

```swift
    @Test("creation succeeds and reports successful follow-ups")
    func createsAndRunsFollowUps() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        seedMeasurement(in: container, at: now)
        var scheduledSnapshot: QuestSnapshot?
        var updatedPayload: WidgetDungeonPayload?
        let coordinator = QuestShortcutCreationCoordinator(
            modelContainer: container,
            scheduleNotifications: { snapshot, _, _ in
                scheduledSnapshot = snapshot
                return .allowed
            },
            updateWidgetSnapshot: { payload in
                updatedPayload = payload
                return true
            }
        )

        let outcome = try await coordinator.create(
            input: try QuestCreationInput(
                title: "Shortcut quest",
                details: "Details",
                deadline: now.addingTimeInterval(3_600),
                importance: .high
            ),
            now: now,
            locale: Locale(identifier: "ko")
        )

        #expect(scheduledSnapshot?.id == outcome.questID)
        #expect(updatedPayload?.quests.contains { $0.id == outcome.questID } == true)
        #expect(outcome.requiresNotificationPermission == false)
        #expect(outcome.followUpFailures.isEmpty)
    }

    @Test("denied notification permission does not roll back creation")
    func deniedPermissionIsCreatedWithGuidance() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: container,
            authorization: .denied,
            widgetUpdated: true
        )

        let outcome = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Quest>()) == 1)
        #expect(outcome.requiresNotificationPermission)
        #expect(outcome.followUpFailures.isEmpty)
    }

    @Test("follow-up failures remain a successful Quest creation")
    func reportsPartialFailureAfterCommit() async throws {
        let container = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(
            container: container,
            authorization: .unavailable,
            widgetUpdated: false
        )

        let outcome = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Quest>()) == 1)
        #expect(outcome.followUpFailures == [.notifications, .widgetSnapshot])
    }

    @Test("container refresh sends the next shortcut write only to the refreshed store")
    func usesRefreshedContainer() async throws {
        let oldContainer = try makeContainer()
        let refreshedContainer = try makeContainer()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let coordinator = makeCoordinator(container: oldContainer, authorization: .allowed, widgetUpdated: true)
        coordinator.updateModelContainer(refreshedContainer)

        _ = try await coordinator.create(input: try shortcutInput(now: now), now: now)

        #expect(try ModelContext(oldContainer).fetchCount(FetchDescriptor<Quest>()) == 0)
        #expect(try ModelContext(refreshedContainer).fetchCount(FetchDescriptor<Quest>()) == 1)
    }
```

Also invoke `create` twice with identical values, assert two different IDs, and use a fresh `ModelContext(container)` to assert two stored rows. There is deliberately no duplicate detector in this release.

- [ ] **Step 5: Define the coordinator outcome and post-commit orchestration**

Create `QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift`:

```swift
import Foundation
import OSLog
import SwiftData
import WidgetKit

nonisolated enum QuestShortcutFollowUpFailure: Hashable, Sendable {
    case notifications
    case widgetSnapshot
}

nonisolated struct QuestShortcutCreationOutcome: Equatable, Sendable {
    let questID: UUID
    let retentionRecordResult: RetentionRecordResult
    let notificationAuthorization: QuestNotificationAuthorization
    let didUpdateWidgetSnapshot: Bool

    var requiresNotificationPermission: Bool {
        notificationAuthorization == .notDetermined || notificationAuthorization == .denied
    }

    var followUpFailures: Set<QuestShortcutFollowUpFailure> {
        var failures: Set<QuestShortcutFollowUpFailure> = []
        if notificationAuthorization == .unavailable { failures.insert(.notifications) }
        if !didUpdateWidgetSnapshot { failures.insert(.widgetSnapshot) }
        return failures
    }
}

@MainActor
final class QuestShortcutCreationCoordinator: Sendable {
    typealias ScheduleNotifications = @MainActor @Sendable (
        QuestSnapshot,
        Date,
        Locale
    ) async -> QuestNotificationAuthorization
    typealias UpdateWidgetSnapshot = @MainActor @Sendable (WidgetDungeonPayload) async -> Bool

    private var modelContainer: ModelContainer
    private let scheduleNotifications: ScheduleNotifications
    private let updateWidgetSnapshot: UpdateWidgetSnapshot
    private let logger = Logger(subsystem: "kr.donminzzi.QuestKeeper", category: "CreateQuestIntent")

    init(
        modelContainer: ModelContainer,
        scheduleNotifications: @escaping ScheduleNotifications,
        updateWidgetSnapshot: @escaping UpdateWidgetSnapshot
    ) {
        self.modelContainer = modelContainer
        self.scheduleNotifications = scheduleNotifications
        self.updateWidgetSnapshot = updateWidgetSnapshot
    }

    func updateModelContainer(_ modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func create(
        input: QuestCreationInput,
        now: Date = .now,
        locale: Locale = .current
    ) async throws -> QuestShortcutCreationOutcome {
        let store = QuestStoreActor(modelContainer: modelContainer)
        let persisted = try await store.create(input: input, createdAt: now)
        let snapshot = QuestSnapshot(
            id: persisted.questID,
            deadline: persisted.deadline,
            completedAt: nil,
            importance: persisted.importance
        )

        let authorization = await scheduleNotifications(snapshot, now, locale)
        let didUpdateWidget: Bool
        do {
            let payload = try await store.snapshotPayload(generatedAt: now)
            didUpdateWidget = await updateWidgetSnapshot(payload)
        } catch {
            didUpdateWidget = false
        }
        if persisted.retentionRecordResult == .failed {
            logger.error("Quest persisted but shortcut retention recording failed")
        }
        return QuestShortcutCreationOutcome(
            questID: persisted.questID,
            retentionRecordResult: persisted.retentionRecordResult,
            notificationAuthorization: authorization,
            didUpdateWidgetSnapshot: didUpdateWidget
        )
    }
}
```

Add a convenience live initializer in the same file. Its notification closure calls `syncWithoutRequestingAuthorization`. Its widget closure runs the synchronous App Group file work inside `Task.detached(priority: .utility)` so the main actor is not blocked, follows the existing `CompleteQuestIntent` precedent, tries `WidgetDungeonSnapshotStore.save` at most twice, returns `false` after both failures, and calls `WidgetCenter.shared.reloadTimelines(ofKind: "QuestKeeperWidget")` only after a successful save. Keep this logic in the coordinator file; a new updater hierarchy would be unnecessary for one call site.

- [ ] **Step 6: Register the stable dependency and keep its container current**

In `QuestKeeper/QuestKeeperApp.swift`, import `AppIntents`, add `private let shortcutCreationCoordinator: QuestShortcutCreationCoordinator`, and construct it immediately after the existing `QuestModelContainer.make` call with that exact `container` and the already-selected `notificationService`:

```swift
let shortcutCreationCoordinator = QuestShortcutCreationCoordinator(
    modelContainer: container,
    notificationService: notificationService
)
self.shortcutCreationCoordinator = shortcutCreationCoordinator
AppDependencyManager.shared.add(dependency: shortcutCreationCoordinator)
```

In the genuine background-return branch, immediately after assigning `sharedModelContainer = refreshed`, add:

```swift
shortcutCreationCoordinator.updateModelContainer(refreshed)
```

Do not instantiate a container in the coordinator, intent, or dependency provider. Extend `QuestKeeperAppTests.appOwnsStableWidgetWriter` to assert the reflected app also owns `shortcutCreationCoordinator`.

- [ ] **Step 7: Run coordinator, notification, and app-wiring tests**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestNotificationServiceTests \
  -only-testing:QuestKeeperTests/QuestShortcutCreationCoordinatorTests \
  -only-testing:QuestKeeperTests/QuestKeeperAppTests
```

Expected: all selected suites pass, the no-prompt fake records no authorization request, partial failures retain the Quest, duplicate invocations retain two Quests, and a refreshed coordinator writes only to the new container.

- [ ] **Step 8: Commit the coordinator boundary**

```bash
git add QuestKeeper/Notifications/QuestNotificationService.swift QuestKeeper/Intents/QuestShortcutCreationCoordinator.swift QuestKeeper/QuestKeeperApp.swift QuestKeeperTests/QuestNotificationServiceTests.swift QuestKeeperTests/QuestShortcutCreationCoordinatorTests.swift QuestKeeperTests/QuestKeeperAppTests.swift
git commit -m "feat(shortcuts): coordinate background quest creation"
```

---

### Task 5: Expose one localized background Create Quest App Shortcut

**Files:**

- Create: `QuestKeeper/Intents/CreateQuestIntent.swift`
- Create: `QuestKeeper/Intents/QuestKeeperAppShortcuts.swift`
- Create: `QuestKeeper/AppShortcuts.xcstrings`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Create: `QuestKeeperTests/CreateQuestIntentTests.swift`
- Modify: `QuestKeeperTests/AppStringsTests.swift`

**Interfaces:**

- Consumes: `QuestCreationInput.shortcut` and `QuestShortcutCreationCoordinator`.
- Produces: `CreateQuestIntent`, `ShortcutQuestImportance`, and one `QuestKeeperAppShortcuts` action.
- Preserves: no `AppEntity`, query, completion action, foreground continuation, or new extension target.

- [ ] **Step 1: Probe the selected SDK before writing beta execution-target syntax**

Run this against the exact Xcode selected for the implementation:

```bash
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
APP_INTENTS_INTERFACE="$SDK_PATH/System/Library/Frameworks/AppIntents.framework/Modules/AppIntents.swiftmodule/arm64-apple-ios-simulator.swiftinterface"
rg -n 'allowedExecutionTargets|IntentExecutionTargets' "$APP_INTENTS_INTERFACE"
```

Expected with the currently selected iOS 26.5 SDK: no matches. Keep `allowedExecutionTargets` out so the feature compiles, and rely on the fact that the new intent source belongs only to the main app target. If the implementation uses a later SDK where both symbols exist, add `static let allowedExecutionTargets: IntentExecutionTargets = .main` and retain the metadata/build checks below. Do not create an App Intents extension either way.

- [ ] **Step 2: Write failing tests for parameter adaptation and result classification**

Create `QuestKeeperTests/CreateQuestIntentTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct CreateQuestIntentTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("intent parameters adapt in title details deadline importance order")
    func adaptsParameters() throws {
        let deadline = now.addingTimeInterval(7_200)
        let input = try CreateQuestIntent.creationInput(
            title: "  Shortcut quest  ",
            details: " First\n\n\nSecond ",
            deadline: deadline,
            importance: .high,
            now: now
        )

        #expect(input.title == "Shortcut quest")
        #expect(input.details == "First\n\nSecond")
        #expect(input.deadline == deadline)
        #expect(input.importance == .high)
    }

    @Test("omitted optional parameters use the approved defaults")
    func adaptsDefaults() throws {
        let input = try CreateQuestIntent.creationInput(
            title: "Shortcut quest",
            details: nil,
            deadline: nil,
            importance: nil,
            now: now
        )

        #expect(input.details == nil)
        #expect(input.deadline == now.addingTimeInterval(3_600))
        #expect(input.importance == .medium)
    }

    @Test("dialog classification distinguishes permission and technical follow-up failures")
    func classifiesDialogs() {
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .allowed,
            followUpFailures: []
        ) == .created)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .denied,
            followUpFailures: []
        ) == .createdNeedsNotificationPermission)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .unavailable,
            followUpFailures: [.notifications]
        ) == .createdWithFollowUpWarning)
        #expect(CreateQuestIntentDialogKind.make(
            authorization: .denied,
            followUpFailures: [.widgetSnapshot]
        ) == .createdWithFollowUpWarningAndNotificationPermission)
    }
}
```

In `AppStringsTests`, resolve `CreateQuestIntent.title`, the four `CreateQuestIntentDialogKind.resource` values, and the three `CreateQuestIntentError.resource` values with both `Locale(identifier: "ko")` and `Locale(identifier: "en")`. Assert the approved copy rather than only checking for non-empty values. Parameter and importance metadata are direct extractor-facing resources, so verify their keys/defaults in extracted metadata and their rendered translations manually instead of duplicating them in a test-only namespace.

- [ ] **Step 3: Run the intent tests and verify they fail**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/CreateQuestIntentTests \
  -only-testing:QuestKeeperTests/AppStringsTests
```

Expected: compile failure because the intent and its localized resources do not exist.

- [ ] **Step 4: Implement the AppEnum adapter, thin intent, and four result states**

Create `QuestKeeper/Intents/CreateQuestIntent.swift`. Declare properties in the approved order and repeat all optional key paths in `parameterSummary` so Shortcuts exposes every field:

```swift
import AppIntents
import Foundation

nonisolated enum ShortcutQuestImportance: String, AppEnum, Sendable {
    case low
    case medium
    case high

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "appIntent.createQuest.importance.type",
            defaultValue: "중요도"
        )
    )
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .low: DisplayRepresentation(title: LocalizedStringResource(
            "appIntent.createQuest.importance.low",
            defaultValue: "낮음"
        )),
        .medium: DisplayRepresentation(title: LocalizedStringResource(
            "appIntent.createQuest.importance.medium",
            defaultValue: "보통"
        )),
        .high: DisplayRepresentation(title: LocalizedStringResource(
            "appIntent.createQuest.importance.high",
            defaultValue: "높음"
        )),
    ]

    var value: Importance {
        switch self {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}

nonisolated enum CreateQuestIntentDialogKind: Equatable, Sendable {
    case created
    case createdNeedsNotificationPermission
    case createdWithFollowUpWarning
    case createdWithFollowUpWarningAndNotificationPermission

    static func make(
        authorization: QuestNotificationAuthorization,
        followUpFailures: Set<QuestShortcutFollowUpFailure>
    ) -> CreateQuestIntentDialogKind {
        let needsPermission = authorization == .notDetermined || authorization == .denied
        switch (!followUpFailures.isEmpty, needsPermission) {
        case (false, false): .created
        case (false, true): .createdNeedsNotificationPermission
        case (true, false): .createdWithFollowUpWarning
        case (true, true): .createdWithFollowUpWarningAndNotificationPermission
        }
    }

    var resource: LocalizedStringResource {
        switch self {
        case .created:
            LocalizedStringResource("appIntent.createQuest.result.created", defaultValue: "퀘스트를 생성했습니다.")
        case .createdNeedsNotificationPermission:
            LocalizedStringResource(
                "appIntent.createQuest.result.permissionRequired",
                defaultValue: "퀘스트를 생성했습니다. 알림은 Quest Keeper에서 권한을 허용하면 받을 수 있습니다."
            )
        case .createdWithFollowUpWarning:
            LocalizedStringResource(
                "appIntent.createQuest.result.partial",
                defaultValue: "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했습니다."
            )
        case .createdWithFollowUpWarningAndNotificationPermission:
            LocalizedStringResource(
                "appIntent.createQuest.result.partialAndPermissionRequired",
                defaultValue: "퀘스트는 생성했지만 일부 후속 작업을 완료하지 못했고 알림 권한도 필요합니다."
            )
        }
    }
}
```

Then add the intent. The `perform` method adapts values, calls the coordinator once, and returns a localized dialog; it contains no SwiftData, notification-center, widget-file, or permission-request code:

```swift
struct CreateQuestIntent: AppIntent {
    static let title = LocalizedStringResource(
        "appIntent.createQuest.title",
        defaultValue: "퀘스트 생성"
    )
    static let description = IntentDescription(LocalizedStringResource(
        "appIntent.createQuest.description",
        defaultValue: "Quest Keeper에 새 퀘스트를 생성합니다."
    ))
    static let supportedModes: IntentModes = .background

    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.title",
        defaultValue: "제목"
    )) var title: String
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.details",
        defaultValue: "설명"
    )) var details: String?
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.deadline",
        defaultValue: "마감"
    )) var deadline: Date?
    @Parameter(title: LocalizedStringResource(
        "appIntent.createQuest.parameter.importance",
        defaultValue: "중요도"
    )) var importance: ShortcutQuestImportance?

    @Dependency private var coordinator: QuestShortcutCreationCoordinator

    static var parameterSummary: some ParameterSummary {
        Summary("Create quest") {
            \.$title
            \.$details
            \.$deadline
            \.$importance
        }
    }

    init() {}

    nonisolated static func creationInput(
        title: String,
        details: String?,
        deadline: Date?,
        importance: ShortcutQuestImportance?,
        now: Date
    ) throws -> QuestCreationInput {
        try QuestCreationInput.shortcut(
            title: title,
            details: details,
            deadline: deadline,
            importance: importance?.value,
            now: now
        )
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date.now
        let input: QuestCreationInput
        do {
            input = try Self.creationInput(
                title: title,
                details: details,
                deadline: deadline,
                importance: importance,
                now: now
            )
        } catch QuestCreationInputError.emptyTitle {
            throw CreateQuestIntentError.emptyTitle
        } catch QuestCreationInputError.deadlineNotInFuture {
            throw CreateQuestIntentError.deadlineNotInFuture
        }

        let outcome: QuestShortcutCreationOutcome
        do {
            outcome = try await coordinator.create(input: input, now: now, locale: .current)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            throw CreateQuestIntentError.persistenceFailed
        }
        let kind = CreateQuestIntentDialogKind.make(
            authorization: outcome.notificationAuthorization,
            followUpFailures: outcome.followUpFailures
        )
        return .result(dialog: IntentDialog(kind.resource))
    }
}
```

Add `nonisolated enum CreateQuestIntentError: LocalizedError, Equatable, Sendable` in the same file with `.emptyTitle`, `.deadlineNotInFuture`, and `.persistenceFailed`. Give each case an internal `resource: LocalizedStringResource` and resolve `errorDescription` through `AppStrings.resolve(resource, locale: .current)`. Mark the pure `creationInput` adapter `nonisolated` as shown so the non-main-actor Swift Testing target can call it synchronously under Swift 6. Quest persistence failure is the only failed action result; notification and widget failures use successful partial-result dialogs because the Quest already exists.

- [ ] **Step 5: Publish exactly one App Shortcut**

Create `QuestKeeper/Intents/QuestKeeperAppShortcuts.swift`:

```swift
import AppIntents

struct QuestKeeperAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateQuestIntent(),
            phrases: ["Create a quest in \(.applicationName)"],
            shortTitle: LocalizedStringResource(
                "appShortcut.createQuest.shortTitle",
                defaultValue: "퀘스트 생성"
            ),
            systemImageName: "plus.square"
        )
    }
}
```

Add Korean and English values for every new metadata, error, result, enum, the `Create quest` summary key, and shortcut-title key to `QuestKeeper/Localizable.xcstrings`. Keep that catalog's source language Korean. The English summary literal is intentional: it avoids a hard-coded Korean literal outside `defaultValue`, while the catalog renders `퀘스트 생성` in Korean.

App Shortcut trigger phrases use their dedicated catalog, not `Localizable.xcstrings`. Create `QuestKeeper/AppShortcuts.xcstrings` with source language English and this exact `stringSet` entry; the `${applicationName}` token must remain in every localized value:

```json
{
  "sourceLanguage": "en",
  "strings": {
    "Create a quest in ${applicationName}": {
      "extractionState": "extracted_with_value",
      "localizations": {
        "en": {
          "stringSet": {
            "state": "translated",
            "values": ["Create a quest in ${applicationName}"]
          }
        },
        "ko": {
          "stringSet": {
            "state": "translated",
            "values": ["${applicationName}에서 퀘스트 생성"]
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

The file-system-synchronized app group includes this new resource without a project-file edit. Do not add QuestKeeperWidget strings because the create action is app-only.

- [ ] **Step 6: Build and inspect extracted App Intents metadata**

```bash
xcodebuild build -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124
METADATA_FILE=/Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124/Build/Products/Debug-iphonesimulator/QuestKeeper.app/Metadata.appintents/extract.actionsdata
test -f "$METADATA_FILE"
jq -e '
  (.actions | keys == ["CreateQuestIntent"]) and
  (.actions.CreateQuestIntent.openAppWhenRun == false) and
  (.actions.CreateQuestIntent.supportedModes == 1) and
  ([.actions.CreateQuestIntent.parameters[] | .name] == ["title", "details", "deadline", "importance"]) and
  ([.actions.CreateQuestIntent.parameters[] | .isOptional] == [false, true, true, true]) and
  ([.actions.CreateQuestIntent.parameters[] | .title.key] == [
    "appIntent.createQuest.parameter.title",
    "appIntent.createQuest.parameter.details",
    "appIntent.createQuest.parameter.deadline",
    "appIntent.createQuest.parameter.importance"
  ]) and
  (.entities | length == 0) and
  (.autoShortcuts | length == 1)
' "$METADATA_FILE"
APP_SHORTCUTS_OUTPUT=$(mktemp -d /tmp/questkeeper-app-shortcuts.XXXXXX)
xcrun xcstringstool compile QuestKeeper/AppShortcuts.xcstrings \
  --output-directory "$APP_SHORTCUTS_OUTPUT" \
  --language en \
  --language ko \
  --dry-run
jq -e '
  .sourceLanguage == "en" and
  .strings["Create a quest in ${applicationName}"].localizations.en.stringSet.values == ["Create a quest in ${applicationName}"] and
  .strings["Create a quest in ${applicationName}"].localizations.ko.stringSet.values == ["${applicationName}에서 퀘스트 생성"]
' QuestKeeper/AppShortcuts.xcstrings
```

Expected: build, both `jq` assertions, and the App Shortcuts catalog dry-run pass. If the extractor changes its private numeric encoding for `supportedModes`, inspect `.actions.CreateQuestIntent.supportedModes`, confirm the source still declares only `.background`, and update only that assertion with evidence; do not weaken the parameter-order, parameter-title, optionality, or trigger-token checks.

- [ ] **Step 7: Run the intent and localization suites**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/CreateQuestIntentTests \
  -only-testing:QuestKeeperTests/AppStringsTests
bash scripts/test-localization.sh QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings
jq empty QuestKeeper/AppShortcuts.xcstrings
```

Expected: parameter/default/dialog tests pass and the Korean/English catalog gate stays green.

- [ ] **Step 8: Verify configuration in the Shortcuts app**

Install and launch the newly built app once so the system indexes its metadata, then open Shortcuts and add Quest Keeper's “퀘스트 생성” action.

Verify all of the following without erasing the Task 1 sentinel app data:

1. The action shows title, details, deadline, and importance in that order.
2. Each field can be changed to “매번 묻기” / “Ask Each Time”.
3. Leaving optional fields unset creates `details == nil`, deadline near invocation time plus one hour, and medium importance.
4. Supplying all fields preserves the normalized description and chosen deadline/importance.
5. An empty title or explicit current/past deadline fails before a row appears.
6. Running the same values twice creates two distinct Quests.
7. Quest Keeper does not foreground while the action runs.

- [ ] **Step 9: Commit the system action**

```bash
git add QuestKeeper/Intents/CreateQuestIntent.swift QuestKeeper/Intents/QuestKeeperAppShortcuts.swift QuestKeeper/AppShortcuts.xcstrings QuestKeeper/Localizable.xcstrings QuestKeeperTests/CreateQuestIntentTests.swift QuestKeeperTests/AppStringsTests.swift
git commit -m "feat(shortcuts): expose create quest action"
```

---

### Task 6: Generalize the existing resolution sheet into one Quest detail surface

**Files:**

- Move: `QuestKeeper/Views/QuestResolutionView.swift` → `QuestKeeper/Views/QuestDetailView.swift`
- Modify: `QuestKeeper/Views/AppStrings.swift`
- Modify: `QuestKeeper/Localizable.xcstrings`
- Create: `QuestKeeperTests/QuestDetailViewTests.swift`
- Modify: `QuestKeeperTests/AppStringsTests.swift`

**Interfaces:**

- Produces: `QuestDetailView` and `QuestDetailCapabilities.make(snapshot:now:)`.
- Preserves: the existing status derivation, retry behavior, editor notification sync, and widget callback.

- [ ] **Step 1: Write the failing capability matrix tests**

Create `QuestKeeperTests/QuestDetailViewTests.swift`:

```swift
import Foundation
import Testing
@testable import QuestKeeper

struct QuestDetailViewTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("pending details can edit but cannot retry")
    func pendingCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(3_600)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(canEdit: true, canRetryTomorrow: false))
    }

    @Test("today's visible grave can retry but cannot edit")
    func visibleGraveCapabilities() {
        let capabilities = QuestDetailCapabilities.make(
            snapshot: snapshot(deadline: now.addingTimeInterval(-60)),
            now: now
        )
        #expect(capabilities == QuestDetailCapabilities(canEdit: false, canRetryTomorrow: true))
    }

    @Test("victories and older graves are read-only")
    func resolvedCapabilities() {
        let victory = snapshot(
            deadline: now.addingTimeInterval(-60),
            completedAt: now.addingTimeInterval(-120)
        )
        let olderGrave = snapshot(deadline: now.addingTimeInterval(-2 * 86_400))

        #expect(QuestDetailCapabilities.make(snapshot: victory, now: now) == .readOnly)
        #expect(QuestDetailCapabilities.make(snapshot: olderGrave, now: now) == .readOnly)
    }

    private func snapshot(deadline: Date, completedAt: Date? = nil) -> QuestSnapshot {
        QuestSnapshot(
            id: UUID(),
            deadline: deadline,
            completedAt: completedAt,
            importance: .medium
        )
    }
}
```

- [ ] **Step 2: Run the detail test and verify it fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestDetailViewTests
```

Expected: compile failure because `QuestDetailCapabilities` does not exist.

- [ ] **Step 3: Rename the existing view and add the explicit action matrix**

```bash
git mv QuestKeeper/Views/QuestResolutionView.swift QuestKeeper/Views/QuestDetailView.swift
```

At the top of the renamed file, add:

```swift
nonisolated struct QuestDetailCapabilities: Equatable, Sendable {
    static let readOnly = QuestDetailCapabilities(
        canEdit: false,
        canRetryTomorrow: false
    )

    let canEdit: Bool
    let canRetryTomorrow: Bool

    static func make(snapshot: QuestSnapshot, now: Date) -> QuestDetailCapabilities {
        switch snapshot.outcome(at: now) {
        case .pending:
            QuestDetailCapabilities(canEdit: true, canRetryTomorrow: false)
        case .grave where snapshot.isVisibleDailyGrave(at: now):
            QuestDetailCapabilities(canEdit: false, canRetryTomorrow: true)
        case .victory, .grave:
            .readOnly
        }
    }
}
```

Rename `QuestResolutionView` to `QuestDetailView`. Keep its `NavigationStack`, close button, and existing status resources. Expand its initializer to receive the existing editor dependencies and callbacks:

```swift
struct QuestDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let quest: Quest
    let now: Date
    let notificationService: QuestNotificationService
    let onAuthorizationChange: (QuestNotificationAuthorization) -> Void
    let onSaved: (Quest) -> Void
    let onRetryTomorrow: (() -> Void)?

    @State private var isEditing = false

    private var capabilities: QuestDetailCapabilities {
        .make(snapshot: quest.snapshot, now: now)
    }
```

Render the same read-only fields in every state:

1. Title and derived status.
2. Description section when `quest.details` is non-`nil`; preserve its line breaks with a regular `Text` and assign `questDetailDetails` as its accessibility identifier.
3. Deadline and localized importance.
4. Completion time when `completedAt` is non-`nil`.

Add an Edit toolbar button only when `capabilities.canEdit`, and present the existing editor over the detail sheet:

```swift
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.commonActionClose) { dismiss() }
                }
                if capabilities.canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.questActionEdit) { isEditing = true }
                            .accessibilityIdentifier("questDetailEditButton")
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                QuestEditor(
                    quest: quest,
                    notificationService: notificationService,
                    onAuthorizationChange: onAuthorizationChange,
                    onSaved: onSaved
                )
            }
```

Keep Retry Tomorrow inside the form only when `capabilities.canRetryTomorrow` and the callback is non-`nil`. Give it `questDetailRetryButton`, call the callback once, then dismiss the detail sheet. Do not expose Edit for graves or completed Quests, and do not expose Retry for older graves.

- [ ] **Step 4: Add only the missing detail copy**

Reuse `questResolutionSection`, `questResolutionStatusLabel`, `questResolutionNavigationTitle`, existing status strings, `questFieldDeadline`, `questFieldDetails`, and the three editor importance strings. Add only:

```swift
    static let questActionEdit = LocalizedStringResource(
        "quest.action.edit",
        defaultValue: "편집"
    )
    static let questFieldCompletedAt = LocalizedStringResource(
        "quest.field.completedAt",
        defaultValue: "완료 시각"
    )
```

Add exact English values `Edit` and `Completed at` to the catalog and assert both locales in `AppStringsTests`. Avoid renaming the existing `quest.resolution.*` keys; they already describe a generic Quest record, and renaming them would be localization churn without user value.

- [ ] **Step 5: Run the detail, action, and localization regressions**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/QuestDetailViewTests \
  -only-testing:QuestKeeperTests/QuestActionsTests \
  -only-testing:QuestKeeperTests/AppStringsTests
bash scripts/test-localization.sh QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings
xcodebuild build -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124
```

Expected: action matrix, retry description preservation, copy, and app compilation all pass.

- [ ] **Step 6: Commit the common detail surface**

```bash
git add QuestKeeper/Views/QuestResolutionView.swift QuestKeeper/Views/QuestDetailView.swift QuestKeeper/Views/AppStrings.swift QuestKeeper/Localizable.xcstrings QuestKeeperTests/QuestDetailViewTests.swift QuestKeeperTests/AppStringsTests.swift
git commit -m "feat(details): add common quest detail screen"
```

---

### Task 7: Route every visible row and notification to the common detail surface

**Files:**

- Modify: `QuestKeeper/ContentView.swift`
- Modify: `QuestKeeper/Views/HomeDungeonBoardView.swift`
- Modify: `QuestKeeper/Views/QuestListSections.swift`
- Modify: `QuestKeeper/Views/QuestRow.swift`
- Modify: `QuestKeeperTests/NotificationRoutingTests.swift`
- Modify: `QuestKeeperUITests/QuestKeeperUITests.swift`

**Interfaces:**

- Consumes: `QuestDetailView` and its capability matrix from Task 6.
- Produces: one `.detail(Quest)` sheet route and one `.detail` notification destination for every Quest outcome.
- Preserves: pending-row horizontal swipe completion/deletion, monster explanation, daily focus membership, and notification parsing.

- [ ] **Step 1: Replace the old notification expectation with the all-state detail matrix**

Keep the `NotificationRouteStore` parser test. Replace `visibleDailyGraveRoutesToRetryDestination` with:

```swift
    @Test("every quest outcome routes to the common detail destination")
    func everyOutcomeRoutesToDetail() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshots = [
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(3_600),
                completedAt: nil,
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-60),
                completedAt: nil,
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-60),
                completedAt: now.addingTimeInterval(-120),
                importance: .medium
            ),
            QuestSnapshot(
                id: UUID(),
                deadline: now.addingTimeInterval(-2 * 86_400),
                completedAt: nil,
                importance: .medium
            ),
        ]

        #expect(snapshots.allSatisfy {
            notificationDestination(for: $0, now: now) == .detail
        })
    }
```

- [ ] **Step 2: Run routing tests and verify the new case fails**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/NotificationRoutingTests
```

Expected: failure because the current destination enum still branches to edit, daily grave, and resolved cases.

- [ ] **Step 3: Collapse sheet and notification routing in `ContentView`**

Rename `EditorRoute` to `QuestSheetRoute`, keep `.create` and `.recoveryCreate`, and replace `.edit`, `.dailyGrave`, and `.resolved` with one case:

```swift
enum QuestSheetRoute: Identifiable {
    case create(QuestEditorDraft?)
    case recoveryCreate(QuestEditorDraft)
    case detail(Quest)

    var id: String {
        switch self {
        case .create: "create"
        case .recoveryCreate: "recovery-create"
        case .detail(let quest): "detail-\(quest.id.uuidString)"
        }
    }
}
```

Change `@State private var route` to this type. Render `.detail` with all existing side-effect adapters:

```swift
                case .detail(let quest):
                    QuestDetailView(
                        quest: quest,
                        now: .now,
                        notificationService: notificationService,
                        onAuthorizationChange: { notificationAuthorization = $0 },
                        onSaved: writeWidgetSnapshot(including:),
                        onRetryTomorrow: {
                            retryTomorrow(quest)
                            route = nil
                        }
                    )
```

The detail capability matrix hides Retry for every ineligible state, so passing the callback once avoids reproducing outcome logic in `ContentView`. Change notification consumption to `route = .detail(quest)` and collapse the destination type:

```swift
nonisolated enum NotificationQuestDestination: Equatable {
    case detail
}

nonisolated func notificationDestination(
    for snapshot: QuestSnapshot,
    now: Date
) -> NotificationQuestDestination {
    .detail
}
```

Keep both parameters because the function is the tested state-routing seam and call sites already provide them. Use `_ = snapshot` and `_ = now` if the compiler warns; do not recreate the removed state branches.

- [ ] **Step 4: Rename the row callback and make completed focus rows tappable**

Across `ContentView`, `HomeDungeonBoardView`, `QuestListSections`, and private `SwipeableQuestRow`, rename `onEdit` to `onOpenDetail`. In `SwipeableQuestRow.onTapGesture`, call `onOpenDetail(quest)` only when the swipe offset is zero; retain the existing reset behavior when an action rail is open.

For completed rows in `dailyFocusSections`, wrap the existing row in a plain button:

```swift
Button {
    onOpenDetail(quest)
} label: {
    QuestRow(
        quest: quest,
        now: now,
        heroAppearance: heroAppearance,
        isCompleted: true
    )
}
.buttonStyle(.plain)
```

Do not add completion or deletion rails to completed rows.

- [ ] **Step 5: Turn daily-grave rows into detail navigation, not inline mutation**

Remove `onRetryTomorrow` and the trailing Retry button from `DailyGraveRow`. Its whole surface remains the existing tombstone presentation. In `QuestListSections`, replace the inline retry closure with a plain button around the row:

```swift
Button {
    onOpenDetail(quest)
} label: {
    DailyGraveRow(
        quest: quest,
        isNewlyMissed: newlyMissedQuestIDs.contains(quest.id)
    )
}
.buttonStyle(.plain)
```

Remove `onRetryTomorrow` from `QuestListSections` and `HomeDungeonBoardView`; `ContentView.retryTomorrow` remains and is passed only into `QuestDetailView`. This enforces “row tap first, action second” without adding another route or confirmation.

- [ ] **Step 6: Add focused UI coverage for pending, daily-grave, and completed rows**

Extend the existing `createQuest` helper with `details: String? = nil`. When details are supplied, find `questDetailsField` by accessibility identifier and type the value before saving. Add these tests to `QuestKeeperUITests.swift`:

1. `testPendingRowOpensDetailEditsDetailsAndKeepsSwipeDelete`: create a pending Quest with `First details`, tap its title, assert `questDetailDetails`, tap `questDetailEditButton`, append `Updated details` in the editor, save, assert the updated detail, close, swipe the row left, and assert the existing Delete action appears. The existing `testSwipeRightThenTapCompleteRemovesQuest` continues to cover the opposite rail.
2. `testDailyGraveDetailOffersRetry`: launch with `-uiTestingInMemoryStore -uiTestingDailyFocusGrave -onboardingVariant control`, tap the seeded grave title, assert Edit is absent and `questDetailRetryButton` exists, tap Retry, then assert the title is present in the pending list and the visible grave section disappears.
3. `testCompletedFocusDetailIsReadOnly`: launch with the daily-focus gate, create and confirm one Quest, complete it through the existing swipe helper, tap the retained completed focus row, and assert title/status exist while both `questDetailEditButton` and `questDetailRetryButton` are absent.

Use accessibility identifiers for the new detail actions and description. Keep localized visible-text assertions for status and section copy so the test also exercises Korean rendering.

- [ ] **Step 7: Run routing and targeted UI tests**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests/NotificationRoutingTests \
  -only-testing:QuestKeeperTests/QuestDetailViewTests
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testPendingRowOpensDetailEditsDetailsAndKeepsSwipeDelete \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testDailyGraveDetailOffersRetry \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testCompletedFocusDetailIsReadOnly \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests/testSwipeToRevealStillWorks \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests/testTappingTheMonsterOpensTheExplanation
```

Expected: all-state routing, pending edit, grave retry, completed read-only, both swipe rails, and the nested monster button behavior pass.

- [ ] **Step 8: Commit the common routing**

```bash
git add QuestKeeper/ContentView.swift QuestKeeper/Views/HomeDungeonBoardView.swift QuestKeeper/Views/QuestListSections.swift QuestKeeper/Views/QuestRow.swift QuestKeeperTests/NotificationRoutingTests.swift QuestKeeperUITests/QuestKeeperUITests.swift
git commit -m "feat(details): route quest rows to details"
```

---

### Task 8: Update current documentation and run the full release gate

**Files:**

- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `BLUEPRINT.md`
- Verify: every file changed by Tasks 1–7

**Interfaces:**

- Documents: `details` as a raw optional fact, the main-app App Intent boundary, and the common detail route.
- Verifies: migration, strict concurrency, app and widget builds, metadata, localization, row behavior, no-prompt behavior, and warm foreground visibility.

- [ ] **Step 1: Update only current architecture facts**

Make these surgical documentation edits:

1. In `README.md`, add `details` to the `Quest` raw-fact list and model example, add one feature bullet for background Shortcuts creation and common read-only detail, and extend manual QA with description/shortcut checks.
2. In `CLAUDE.md`, add `title` and optional `details` to the persisted raw-fact wording, update the moved `QuestTitlePolicy` location to `QuestKeeperShared/`, and document that `CreateQuestIntent` runs from the main app target through the app-owned container, never asks for notification permission, and excludes details from widget JSON.
3. In `BLUEPRINT.md`, add `details` to the raw-fact lists and Phase 1 model checklist. Add a short `## Shipped Extensions` section before `## Backlog` for optional descriptions, the common detail surface, and the one background Create Quest App Shortcut. Do not rewrite completed phase history or old specs.

Keep `QuestSnapshot` documented as derivation-only without title or details. Keep `WidgetQuestPayload` documented without details.

- [ ] **Step 2: Reconfirm the simulator and review the exact change set before running heavy jobs**

```bash
xcrun simctl list devices available
git status --short
git diff --stat main...HEAD
git diff --name-status main...HEAD
```

Expected: the chosen UDID still exists, only AND-124 paths are changed, no dependency manifest or project file changed, and no author-unknown file is included. If the UDID drifted, replace it consistently in the remaining commands.

- [ ] **Step 3: Run explicit-path formatting and static checks without rewriting unrelated files**

Use zsh's newline-array expansion so paths with spaces remain intact and no implicit word splitting is assumed:

```zsh
typeset -U changed_paths
changed_paths=(
  "${(@f)$(git diff --name-only --diff-filter=ACMR main...HEAD -- '*.swift' '*.md' '*.xcstrings')}"
  "${(@f)$(git diff --name-only --diff-filter=ACMR -- '*.swift' '*.md' '*.xcstrings')}"
  "${(@f)$(git ls-files --others --exclude-standard -- '*.swift' '*.md' '*.xcstrings')}"
)
changed_paths=("${(@)changed_paths:#}")
(( ${#changed_paths[@]} > 0 ))
trunk fmt --no-fix "${changed_paths[@]}"
trunk check --no-fix "${changed_paths[@]}"
git diff --check main...HEAD
git diff --check
jq empty QuestKeeper/Localizable.xcstrings QuestKeeper/AppShortcuts.xcstrings QuestKeeperWidget/Localizable.xcstrings
```

Expected: no formatter changes are required, Trunk reports no new issue, diff whitespace is valid, and both catalogs parse. If `trunk fmt --no-fix` reports a required change, run `trunk fmt` with the same explicit array only, inspect the resulting diff, and include the mechanical correction with the task that owns that file; never run a bare repository-wide formatter.

- [ ] **Step 4: Run the complete unit-test gate**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperTests
```

Expected: every `QuestKeeperTests` test passes, including migration, details normalization, common creation, actor storage, measurement validation, no-prompt notifications, coordinator partial success, intent adaptation, detail capabilities, and notification routing.

- [ ] **Step 5: Run the focused end-to-end UI regression gate**

```bash
xcodebuild test -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124 \
  -parallel-testing-enabled NO \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testPendingRowOpensDetailEditsDetailsAndKeepsSwipeDelete \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testDailyGraveDetailOffersRetry \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testCompletedFocusDetailIsReadOnly \
  -only-testing:QuestKeeperUITests/QuestKeeperUITests/testSwipeRightThenTapCompleteRemovesQuest \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests/testSwipeToRevealStillWorks \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests/testSwipeToRevealStillWorksWhenStartingOnTheMonsterButton \
  -only-testing:QuestKeeperUITests/MonsterExplanationUITests/testTappingTheMonsterOpensTheExplanation
```

Expected: details navigation/editing, grave retry, completed read-only behavior, left/right swipe rails, and monster-button interaction all pass.

- [ ] **Step 6: Run localization, model, app, widget, and metadata gates**

Run these sequentially to respect the one-heavy-mobile-job limit:

```bash
bash scripts/test-localization.sh QuestKeeper/Localizable.xcstrings QuestKeeperWidget/Localizable.xcstrings
jq -e '
  .strings["Create a quest in ${applicationName}"].localizations.en.stringSet.values == ["Create a quest in ${applicationName}"] and
  .strings["Create a quest in ${applicationName}"].localizations.ko.stringSet.values == ["${applicationName}에서 퀘스트 생성"]
' QuestKeeper/AppShortcuts.xcstrings
APP_SHORTCUTS_OUTPUT=$(mktemp -d /tmp/questkeeper-app-shortcuts-final.XXXXXX)
xcrun xcstringstool compile QuestKeeper/AppShortcuts.xcstrings \
  --output-directory "$APP_SHORTCUTS_OUTPUT" \
  --language en \
  --language ko \
  --dry-run
! rg -n '(var|let) +(hp|isDead|mobLevel|urgency|victories|graves|outcome|retry|monster|notificationID|isNotificationScheduled|reminderEnabled|lastNotificationFiredAt|widgetID)' QuestKeeper/Models/ QuestKeeperShared/Quest.swift
xcodebuild build -scheme QuestKeeper \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124
xcodebuild build -scheme QuestKeeperWidget \
  -project QuestKeeper.xcodeproj \
  -destination 'platform=iOS Simulator,id=24B14321-156A-4BC4-97DC-0183AD675A8D' \
  -derivedDataPath /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124-widget
METADATA_FILE=/Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124/Build/Products/Debug-iphonesimulator/QuestKeeper.app/Metadata.appintents/extract.actionsdata
test -f "$METADATA_FILE"
jq -e '
  (.actions | keys == ["CreateQuestIntent"]) and
  ([.actions.CreateQuestIntent.parameters[] | .name] == ["title", "details", "deadline", "importance"]) and
  ([.actions.CreateQuestIntent.parameters[] | .isOptional] == [false, true, true, true]) and
  (.entities | length == 0) and
  (.autoShortcuts | length == 1)
' "$METADATA_FILE"
```

Expected: both localization catalogs pass, no derived field enters persistence, app and widget compile under Swift 6, and the app artifact exposes exactly one four-parameter creation shortcut with no entity.

- [ ] **Step 7: Prove install-over lightweight migration with the preserved sentinel**

Install the Task 8 app artifact over the untouched baseline installation from Task 1; do not uninstall first:

```bash
xcrun simctl install 24B14321-156A-4BC4-97DC-0183AD675A8D \
  /Volumes/dongminyu/Xcode/DerivedData/QuestKeeper-AND-124/Build/Products/Debug-iphonesimulator/QuestKeeper.app
xcrun simctl launch 24B14321-156A-4BC4-97DC-0183AD675A8D kr.donminzzi.QuestKeeper
```

Manually open `AND-124 legacy sentinel`, confirm its title/deadline/importance are intact, its missing description is treated as `nil`, and the app and widget still render. This is the real install-over proof paired with `QuestModelMigrationTests`; do not replace it with a clean install.

- [ ] **Step 8: Run the Korean/English Shortcuts and warm-foreground QA matrix**

After capturing the sentinel migration evidence, use a disposable clean installation when an undetermined notification state is required. Uninstalling erases QuestKeeper data, so do it only after the sentinel check or on a separate disposable simulator.

Verify in Korean, then repeat the visible metadata/result/detail checks in English:

1. Launch Quest Keeper once without creating a Quest, send it to the background, then run Create Quest from Shortcuts with notification authorization still undetermined. Confirm no permission sheet appears and Quest Keeper does not foreground.
2. Reactivate the already-running app. Confirm the newly created row appears without terminating the app, tap it, and confirm the description and chosen importance/deadline are visible.
3. Run the all-omitted-optional-fields case. Confirm no description section, medium importance, and a deadline approximately one hour after invocation.
4. Run the fully supplied case with surrounding spaces and three consecutive newlines. Confirm edge trimming and at most two consecutive newlines in detail.
5. Configure all four fields as “매번 묻기” / “Ask Each Time” and complete one prompted run.
6. Enter 1,001 characters and an abusive combining-mark sequence through Shortcuts. Confirm the saved value respects the 1,000-Character and 4,000-scalar bounds without a crash.
7. Supply whitespace-only details and confirm detail treats it as `nil`.
8. Supply an empty title and a current/past explicit deadline in separate runs. Confirm neither creates a row.
9. Run the same valid action twice and confirm two distinct rows.
10. With notification permission already allowed, run once and inspect pending notifications; with permission denied, run once and confirm the result gives app-permission guidance while the Quest still exists.
11. Tap pending, visible daily grave, completed daily-focus, and notification-routed Quests. Confirm the state matrix is Edit, Retry Tomorrow, read-only, and common detail respectively.
12. Confirm widget rows and widget JSON expose no description and still refresh after shortcut creation.

Technical partial-failure combinations remain deterministic unit-test coverage because forcing App Group I/O and notification-center failures through the simulator UI would require test-only production hooks.

- [ ] **Step 9: Commit current documentation after the gate is green**

Before committing, present this exact commit sequence and any deviations to the operator: `docs: add iOS shortcuts and quest details plan` first, then `feat(model)`, `feat(editor)`, `feat(shortcuts)` store, `feat(shortcuts)` coordinator, `feat(shortcuts)` action, `feat(details)` screen, `feat(details)` routing, then this documentation commit. Stage only the documented paths.

```bash
git add README.md CLAUDE.md BLUEPRINT.md
git commit -m "docs: document shortcut creation boundary"
```

- [ ] **Step 10: Verify final history and working-tree state**

```bash
git status --short
git log --oneline --decorate main..HEAD
git diff --check main...HEAD
git diff --stat main...HEAD
git diff --name-status main...HEAD
```

Expected: the working tree is clean, the semantic commit sequence is present, the plan and current docs are tracked, the diff contains no manifest/lockfile/project-file churn, and only AND-124 scope remains.

---

## Execution Handoff

After implementation approval and before creating a branch or worktree, commit this currently untracked plan from the current checkout so the new worktree includes it. Inspect status first and stop for operator direction if the staged-name check includes a path other than this plan:

```bash
git status --short
git add docs/plans/2026-08-14-ios-shortcuts-and-quest-details.md
git diff --cached --name-only
git commit -m "docs: add iOS shortcuts and quest details plan"
```

Then verify the repository root with `git -C /Volumes/dongminyu/Development/01_personal/quest-keeper rev-parse --show-toplevel`, confirm `main` is still the intended base, and create the recommended branch or an isolated worktree through `superpowers:using-git-worktrees`. Do not reuse a dirty worktree or discard author-unknown changes.

Recommended execution mode: `superpowers:subagent-driven-development`, one task at a time with review after each task. Inline execution with `superpowers:executing-plans` is acceptable if the operator prefers a single worker. In either mode, the root agent owns the branch, commits, and final verification; implementation workers receive explicit file ownership and never stage or commit.
