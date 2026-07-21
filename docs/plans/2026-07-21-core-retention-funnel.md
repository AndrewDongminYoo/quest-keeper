# Core Retention Funnel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Do not dispatch parallel agents because the persistence, recorder, reporter, and integration tasks consume interfaces created by the preceding task and share one worktree.

**Goal:** Implement AND-33 as a dependency-free local event journal that records QuestKeeper's first-value and retention funnel, detects duplicate and missing events, and generates reproducible synthetic and live baselines.

**Architecture:** Add two SwiftData measurement models beside `Quest` in the existing App Group store while leaving `Quest` unchanged. Route four canonical events through a small shared recorder, calculate all metrics through pure `Sendable` snapshots with explicit clock and calendar inputs, and atomically write a privacy-safe JSON baseline on genuine app activation.

**Tech Stack:** Swift 6, SwiftData, Swift Testing, Foundation `Codable`, OSLog, App Groups, SwiftUI scene lifecycle, WidgetKit/AppIntents integration

## Global Constraints

- Work only in `/Volumes/dongminyu/Development/01_personal/QuestKeeper/.worktrees/and-33-retention-funnel` on `feature/and-33-retention-funnel`.
- Preserve `Quest` exactly; add no analytics, retention, retry-count, session, or derived-state property to it.
- Do not add Firebase, another analytics SDK, a backend, an account system, network transmission, or a user-facing analytics dashboard.
- Store no quest title, notification text, free-form input, device-vendor identifier, advertising identifier, email, device name, location, or IP address in measurement records, rendered reports, or logs.
- Keep Korean comments and user-facing strings unchanged.
- Preserve current app, widget, notification, quest outcome, daily-grave, and App Group behavior.
- Do not hand-edit `QuestKeeper.xcodeproj/project.pbxproj`; synchronized groups automatically include new Swift files in `QuestKeeperShared`, `QuestKeeper`, and `QuestKeeperTests`.
- Keep parallel testing disabled and use at most one heavy mobile job at a time.
- Every test uses explicit dates, calendars, time zones, UUIDs, and report boundaries; production-only `.now` and `.current` values stay at integration seams.
- Before each commit, inspect the staged diff and keep only that task's implementation and direct tests together.

---

## File Structure

Create these focused files:

- `QuestKeeperShared/RetentionEvent.swift`: SwiftData installation/event models, raw event enums, and pure snapshots.
- `QuestKeeperShared/RetentionEventRecorder.swift`: installation lookup, stable deduplication keys, canonical record functions, and privacy-safe error logging.
- `QuestKeeperShared/RetentionReport.swift`: validation, canonicalization, funnel calculations, data-quality results, and Markdown rendering.
- `QuestKeeperShared/RetentionBaselineStore.swift`: schema-versioned JSON encoding, decoding, and atomic App Group file persistence.
- `QuestKeeper/Measurement/RetentionBaselineWriter.swift`: app-only orchestration that records activation, fetches snapshots, calculates the live report, and writes JSON.
- `QuestKeeperTests/RetentionPersistenceTests.swift`: model schema, stable installation, privacy shape, and existing-store preservation.
- `QuestKeeperTests/RetentionEventRecorderTests.swift`: exact-once event construction and deduplication keys.
- `QuestKeeperTests/RetentionReportTests.swift`: funnel, D1/D7, WAU, repeated completion, duplicate, omission, ordering, and rendering coverage.
- `QuestKeeperTests/RetentionBaselineStoreTests.swift`: JSON schema and atomic store behavior.
- `QuestKeeperTests/Fixtures/RetentionBaselineFixture.swift`: deterministic multi-installation synthetic fixture.
- `docs/notes/012-retention-baseline.md`: generated fixture report, explicitly labeled synthetic.

Modify only these existing files:

- `QuestKeeperShared/QuestModelContainer.swift`: include the two measurement models and expose a URL-injected test seam.
- `QuestKeeperShared/QuestStoreActor.swift`: record one widget completion event before its existing save.
- `QuestKeeper/QuestKeeperApp.swift`: own the baseline writer and distinguish initial/background activations from inactive peeks.
- `QuestKeeper/ContentView.swift`: record app completion and retry events at the existing fact mutations.
- `QuestKeeper/Views/QuestEditor.swift`: record creation only in the new-quest branch.
- `QuestKeeperTests/QuestStoreActorTests.swift`: assert widget completion emission and existing idempotence.
- `QuestKeeperTests/QuestKeeperAppTests.swift`: assert stable writer ownership and activation gate behavior through an extracted pure helper.

Do not create a generic analytics protocol, event-property dictionary, dependency-injection framework, repository layer, dashboard view, export UI, or background upload service.

---

### Task 1: Add The Measurement Schema Without Losing Existing Quests

**Files:**

- Create: `QuestKeeperShared/RetentionEvent.swift`
- Modify: `QuestKeeperShared/QuestModelContainer.swift:10-20`
- Create: `QuestKeeperTests/RetentionPersistenceTests.swift`

**Interfaces:**

- Consumes: existing `Quest` model and `WidgetDungeonSnapshotStore.appGroupIdentifier`.
- Produces: `RetentionInstallation`, `RetentionEvent`, `RetentionEventName`, `RetentionEventSource`, `RetentionInstallationSnapshot`, `RetentionEventSnapshot`, and `QuestModelContainer.make(storeURL:)`.

- [ ] **Step 1: Write the failing persistence and privacy tests**

Create `QuestKeeperTests/RetentionPersistenceTests.swift` with fixed identifiers and these tests:

```swift
import Foundation
import SwiftData
import Testing
@testable import QuestKeeper

@MainActor
struct RetentionPersistenceTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let eventID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let startedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("measurement models persist beside Quest without changing Quest")
    func measurementModelsPersistBesideQuest() throws {
        let container = try measurementContainer()
        let quest = Quest(title: "비공개 제목", deadline: startedAt.addingTimeInterval(3600), importance: .medium)
        let installation = RetentionInstallation(
            installationID: installationID,
            measurementStartedAt: startedAt
        )
        let event = RetentionEvent(
            id: eventID,
            name: .questCreated,
            installationID: installationID,
            occurredAt: startedAt,
            source: .app,
            questID: questID,
            deduplicationKey: "quest_created:\(installationID):\(questID)"
        )

        container.mainContext.insert(quest)
        container.mainContext.insert(installation)
        container.mainContext.insert(event)
        try container.mainContext.save()

        #expect(try container.mainContext.fetch(FetchDescriptor<Quest>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionEvent>()).count == 1)
        #expect(event.snapshot.nameRawValue == "quest_created")
        #expect(event.snapshot.sourceRawValue == "app")
    }

    @Test("event snapshot exposes only the approved privacy fields")
    func eventSnapshotHasApprovedShape() {
        let snapshot = RetentionEventSnapshot(
            id: eventID,
            schemaVersion: 1,
            nameRawValue: "quest_created",
            installationID: installationID,
            occurredAt: startedAt,
            sourceRawValue: "app",
            questID: questID,
            deduplicationKey: "key"
        )

        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))
        #expect(labels == [
            "id", "schemaVersion", "nameRawValue", "installationID",
            "occurredAt", "sourceRawValue", "questID", "deduplicationKey",
        ])
    }

    private func measurementContainer() throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
```

Add a disk-backed migration test in the same file.
Create one store with the legacy `Schema([Quest.self])`, save a known quest, release that container inside a nested scope, reopen the same URL with `QuestModelContainer.make(storeURL:)`, and require that the quest title, deadline, importance, and completion remain byte-for-byte equivalent while both measurement tables are empty.

```swift
@Test("adding measurement models preserves a pre-populated Quest store")
func addingModelsPreservesExistingStore() throws {
    let storeURL = FileManager.default.temporaryDirectory
        .appending(path: "QuestKeeper-retention-\(UUID().uuidString).store")
    let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!

    do {
        let legacySchema = Schema([Quest.self])
        let legacyConfiguration = ModelConfiguration(schema: legacySchema, url: storeURL)
        let legacy = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
        legacy.mainContext.insert(Quest(
            id: questID,
            title: "기존 퀘스트",
            deadline: startedAt.addingTimeInterval(7200),
            importance: .high,
            completedAt: startedAt.addingTimeInterval(60)
        ))
        try legacy.mainContext.save()
    }

    let upgraded = try QuestModelContainer.make(storeURL: storeURL)
    let quests = try upgraded.mainContext.fetch(FetchDescriptor<Quest>())

    #expect(quests.count == 1)
    #expect(quests.first?.id == questID)
    #expect(quests.first?.title == "기존 퀘스트")
    #expect(quests.first?.importance == .high)
    #expect(try upgraded.mainContext.fetch(FetchDescriptor<RetentionEvent>()).isEmpty)
    #expect(try upgraded.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).isEmpty)
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionPersistenceTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because `RetentionInstallation`, `RetentionEvent`, and `make(storeURL:)` do not exist.

- [ ] **Step 3: Add the minimal models and pure snapshots**

Create `QuestKeeperShared/RetentionEvent.swift` with these exact stored fields and raw enums:

```swift
import Foundation
import SwiftData

nonisolated enum RetentionEventName: String, Codable, CaseIterable, Sendable {
    case appActivated = "app_activated"
    case questCreated = "quest_created"
    case questCompleted = "quest_completed"
    case questRetried = "quest_retried"
}

nonisolated enum RetentionEventSource: String, Codable, CaseIterable, Sendable {
    case app
    case widget
}

@Model
final class RetentionInstallation {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var installationID: UUID
    var measurementStartedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        installationID: UUID = UUID(),
        measurementStartedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.installationID = installationID
        self.measurementStartedAt = measurementStartedAt
    }

    var snapshot: RetentionInstallationSnapshot {
        RetentionInstallationSnapshot(
            schemaVersion: schemaVersion,
            installationID: installationID,
            measurementStartedAt: measurementStartedAt
        )
    }
}

@Model
final class RetentionEvent {
    static let currentSchemaVersion = 1

    var id: UUID
    var schemaVersion: Int
    var nameRawValue: String
    var installationID: UUID
    var occurredAt: Date
    var sourceRawValue: String
    var questID: UUID?
    var deduplicationKey: String

    init(
        id: UUID = UUID(),
        schemaVersion: Int = currentSchemaVersion,
        name: RetentionEventName,
        installationID: UUID,
        occurredAt: Date,
        source: RetentionEventSource,
        questID: UUID?,
        deduplicationKey: String
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.nameRawValue = name.rawValue
        self.installationID = installationID
        self.occurredAt = occurredAt
        self.sourceRawValue = source.rawValue
        self.questID = questID
        self.deduplicationKey = deduplicationKey
    }

    var snapshot: RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: id,
            schemaVersion: schemaVersion,
            nameRawValue: nameRawValue,
            installationID: installationID,
            occurredAt: occurredAt,
            sourceRawValue: sourceRawValue,
            questID: questID,
            deduplicationKey: deduplicationKey
        )
    }
}

nonisolated struct RetentionInstallationSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let installationID: UUID
    let measurementStartedAt: Date
}

nonisolated struct RetentionEventSnapshot: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let schemaVersion: Int
    let nameRawValue: String
    let installationID: UUID
    let occurredAt: Date
    let sourceRawValue: String
    let questID: UUID?
    let deduplicationKey: String

    var name: RetentionEventName? { RetentionEventName(rawValue: nameRawValue) }
    var source: RetentionEventSource? { RetentionEventSource(rawValue: sourceRawValue) }
}
```

- [ ] **Step 4: Extend the shared container without changing its production call sites**

Replace the body of `QuestModelContainer` with one schema factory and an optional test URL:

```swift
enum QuestModelContainer {
    nonisolated static func make(storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Quest.self, RetentionInstallation.self, RetentionEvent.self])
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(WidgetDungeonSnapshotStore.appGroupIdentifier)
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

If the disk-backed migration test proves that the unversioned lightweight change cannot open the legacy store, stop this task before editing call sites.
Introduce `QuestKeeperSchemaV1`, `QuestKeeperSchemaV2`, and a single lightweight `SchemaMigrationPlan` whose only change is adding the two measurement models, then rerun the same preservation test.
Do not synthesize events or alter `Quest` during migration.

- [ ] **Step 5: Run persistence tests and the existing store-actor tests**

Run:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionPersistenceTests -only-testing:QuestKeeperTests/QuestStoreActorTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS with the known quest preserved and empty measurement tables after upgrade.

- [ ] **Step 6: Commit the schema boundary**

```bash
git add QuestKeeperShared/RetentionEvent.swift QuestKeeperShared/QuestModelContainer.swift QuestKeeperTests/RetentionPersistenceTests.swift
git diff --cached --check
git commit -m "feat(metrics): add local retention schema"
```

---

### Task 2: Record The Four Canonical Events Exactly Once

**Files:**

- Create: `QuestKeeperShared/RetentionEventRecorder.swift`
- Modify: `QuestKeeper/Views/QuestEditor.swift:84-101`
- Modify: `QuestKeeper/ContentView.swift:139-158`
- Modify: `QuestKeeperShared/QuestStoreActor.swift:12-22`
- Create: `QuestKeeperTests/RetentionEventRecorderTests.swift`
- Modify: `QuestKeeperTests/QuestStoreActorTests.swift:14-70`

**Interfaces:**

- Consumes: `RetentionInstallation`, `RetentionEvent`, and callers' existing `ModelContext`.
- Produces: `RetentionRecordResult` plus `recordActivation`, `recordQuestCreated`, `recordQuestCompleted`, and `recordQuestRetried` static functions.

- [ ] **Step 1: Write failing recorder tests for stable identity and exact deduplication**

Create an in-memory schema containing all three models and test the four functions with fixed IDs and dates.
The core expectations are:

```swift
@Test("recorder creates one stable installation and deduplicates each canonical key")
func recorderDeduplicatesCanonicalKeys() throws {
    let container = try measurementContainer()
    let context = container.mainContext
    let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let questID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    context.insert(RetentionInstallation(installationID: installationID, measurementStartedAt: now))

    #expect(RetentionEventRecorder.recordActivation(sessionID: sessionID, at: now, in: context) == .inserted)
    #expect(RetentionEventRecorder.recordActivation(sessionID: sessionID, at: now, in: context) == .duplicate)
    #expect(RetentionEventRecorder.recordQuestCreated(questID: questID, at: now, in: context) == .inserted)
    #expect(RetentionEventRecorder.recordQuestCreated(questID: questID, at: now, in: context) == .duplicate)
    #expect(RetentionEventRecorder.recordQuestCompleted(questID: questID, completedAt: now, source: .app, in: context) == .inserted)
    #expect(RetentionEventRecorder.recordQuestCompleted(questID: questID, completedAt: now, source: .app, in: context) == .duplicate)

    let events = try context.fetch(FetchDescriptor<RetentionEvent>())
    #expect(events.count == 3)
}
```

Add separate tests proving:

- a second completion time for the same quest inserts a second completion event;
- app and widget calls with the same quest ID and completion time resolve to one canonical key;
- retry keys differ when the effective new deadline differs;
- a failed installation fetch returns `.failed` and does not throw into the product path;
- event rows contain no title or arbitrary properties.

- [ ] **Step 2: Run the focused recorder tests and verify failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionEventRecorderTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because `RetentionEventRecorder` and `RetentionRecordResult` do not exist.

- [ ] **Step 3: Implement the nonthrowing recorder**

Create `QuestKeeperShared/RetentionEventRecorder.swift` with this public surface:

```swift
import Foundation
import OSLog
import SwiftData

nonisolated enum RetentionRecordResult: Equatable, Sendable {
    case inserted
    case duplicate
    case failed
}

nonisolated enum RetentionEventRecorder {
    private static let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "RetentionMeasurement"
    )

    static func recordActivation(
        sessionID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .appActivated,
            source: .app,
            occurredAt: occurredAt,
            questID: nil,
            keyComponent: sessionID.uuidString,
            in: context
        )
    }

    static func recordQuestCreated(
        questID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCreated,
            source: .app,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: questID.uuidString,
            in: context
        )
    }

    static func recordQuestCompleted(
        questID: UUID,
        completedAt: Date,
        source: RetentionEventSource,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCompleted,
            source: source,
            occurredAt: completedAt,
            questID: questID,
            keyComponent: "\(questID.uuidString):\(completedAt.timeIntervalSinceReferenceDate.bitPattern)",
            in: context
        )
    }

    static func recordQuestRetried(
        questID: UUID,
        newDeadline: Date,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questRetried,
            source: .app,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: "\(questID.uuidString):\(newDeadline.timeIntervalSinceReferenceDate.bitPattern)",
            in: context
        )
    }
}
```

Implement one private `record` method that:

1. fetches the oldest `RetentionInstallation` with `fetchLimit = 1`;
2. inserts a new installation with `measurementStartedAt = occurredAt` only when none exists;
3. constructs `"<event-name>:<installation-id>:<key-component>"`;
4. fetches `RetentionEvent` by the exact deduplication key with `fetchLimit = 1`;
5. returns `.duplicate` without insertion when found;
6. inserts exactly one `RetentionEvent` and returns `.inserted` otherwise;
7. catches every fetch error, logs only `name.rawValue` and `String(describing: error)`, and returns `.failed`.

Do not call `context.save()` inside the recorder.
The canonical mutation owner keeps its existing save/autosave boundary, which lets the event join the same context without introducing a second transaction.

- [ ] **Step 4: Wire creation, app completion, retry, and widget completion**

In `QuestEditor.save()`, capture one `savedAt = Date.now` before branching.
Call `recordQuestCreated` only after inserting a new quest; do not call it in the edit branch.

In `ContentView.complete`, call `recordQuestCompleted` immediately after `QuestActions.complete` with the already captured `completedAt` and `.app`.

In `ContentView.retryTomorrow`, call `recordQuestRetried` immediately after `QuestActions.retryTomorrow` with `quest.deadline` and the same `now` value.

In `QuestStoreActor.complete`, add this before the existing `modelContext.save()`:

```swift
_ = RetentionEventRecorder.recordQuestCompleted(
    questID: id,
    completedAt: now,
    source: .widget,
    in: modelContext
)
```

The existing missing/already-completed guards remain before the recorder call, so stale widget taps create no event.

- [ ] **Step 5: Extend widget actor tests**

Change the test container schema to include all three models.
After a successful completion require one `.questCompleted` event with `.widget` source.
After the second stale call require `wrote == false` and the event count still equal to one.
Keep the existing missing-ID no-op test and require no event.

- [ ] **Step 6: Run the recorder and mutation tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionEventRecorderTests -only-testing:QuestKeeperTests/QuestStoreActorTests -only-testing:QuestKeeperTests/QuestActionsTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS; successful mutations create one event and duplicate/no-op paths create none.

- [ ] **Step 7: Commit the canonical event seams**

```bash
git add QuestKeeperShared/RetentionEventRecorder.swift QuestKeeperShared/QuestStoreActor.swift QuestKeeper/ContentView.swift QuestKeeper/Views/QuestEditor.swift QuestKeeperTests/RetentionEventRecorderTests.swift QuestKeeperTests/QuestStoreActorTests.swift
git diff --cached --check
git commit -m "feat(metrics): record core retention events"
```

---

### Task 3: Calculate The Funnel And Detect Data-Quality Failures

**Files:**

- Create: `QuestKeeperShared/RetentionReport.swift`
- Create: `QuestKeeperTests/RetentionReportTests.swift`
- Create: `QuestKeeperTests/Fixtures/RetentionBaselineFixture.swift`

**Interfaces:**

- Consumes: arrays of `RetentionInstallationSnapshot` and `RetentionEventSnapshot` plus explicit `asOf`, `Calendar`, and reporting week.
- Produces: `RetentionReport`, `RetentionRate`, `RetentionDataQuality`, `RetentionScenarioExpectation`, `RetentionScenarioValidation`, `RetentionReport.make(...)`, and `renderMarkdown()`.

- [ ] **Step 1: Create the deterministic fixture**

Create `RetentionBaselineFixture` as a pure test helper with:

```swift
enum RetentionBaselineFixture {
    static let version = 1
    static let timeZone = TimeZone(identifier: "Asia/Seoul")!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        value.firstWeekday = 2
        return value
    }
    static let asOf = ISO8601DateFormatter().date(from: "2026-07-13T15:00:00Z")!
    static let reportingWeek = DateInterval(
        start: ISO8601DateFormatter().date(from: "2026-07-05T15:00:00Z")!,
        end: ISO8601DateFormatter().date(from: "2026-07-12T15:00:00Z")!
    )
}
```

Use four fixed installation UUIDs and fixed event UUIDs.
Shape the fixture so the expected canonical metrics are explicit:

- 4 first activations;
- 3 first-value installations;
- 2 first completions;
- 4 D1-eligible installations with 2 retained;
- 3 D7-eligible installations with 1 retained;
- 3 weekly active installations;
- 1 weekly active installation with at least two completions;
- zero quality problems in the canonical fixture.

Expose `installations`, `events`, and `expectation` as static values.
The expectation contains the fixture's required deduplication keys and an empty forbidden-key set.

- [ ] **Step 2: Write failing report tests**

Create tests for the exact fixture values:

```swift
@Test("fixture produces the approved funnel and retention denominators")
func fixtureProducesApprovedMetrics() {
    let report = RetentionReport.make(
        installations: RetentionBaselineFixture.installations,
        events: RetentionBaselineFixture.events,
        asOf: RetentionBaselineFixture.asOf,
        calendar: RetentionBaselineFixture.calendar,
        reportingWeek: RetentionBaselineFixture.reportingWeek,
        expectation: RetentionBaselineFixture.expectation
    )

    #expect(report.firstValue == RetentionRate(achieved: 3, eligible: 4))
    #expect(report.firstCompletion == RetentionRate(achieved: 2, eligible: 3))
    #expect(report.d1 == RetentionRate(achieved: 2, eligible: 4))
    #expect(report.d7 == RetentionRate(achieved: 1, eligible: 3))
    #expect(report.weeklyActiveInstallations == 3)
    #expect(report.weeklyRepeatedCompletion == RetentionRate(achieved: 1, eligible: 3))
    #expect(report.dataQuality.status == .complete)
}
```

Add focused tests that mutate one fixture input at a time:

- remove one required event and require that exact deduplication key in `missingKeys`;
- duplicate one event row with a new row UUID and require `duplicateCountsByEvent[RetentionEventName.questCompleted.rawValue] == 1`;
- add a forbidden key and require it in `forbiddenKeys`;
- add a completion before creation and require `orphanCompletionCount == 1` with no funnel credit;
- add unknown event/source raw values and require `unsupportedCount == 2`;
- add events before measurement start and after `asOf` and require separate counts;
- add an activation on D2 without D1 and require no D1 credit;
- add an installation younger than seven calendar days and require exclusion from the D7 denominator;
- place completions on both sides of the supplied week boundary and require only in-range completions;
- use two rows with one deduplication key and require the earliest timestamp, then smallest UUID, as representative;
- render Markdown twice and require byte-for-byte equality.

- [ ] **Step 3: Run report tests and verify failure**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: FAIL because the report and validator types do not exist.

- [ ] **Step 4: Implement fixed report value types**

Create these `nonisolated`, `Codable`, `Equatable`, `Sendable` types:

```swift
struct RetentionRate: Codable, Equatable, Sendable {
    let achieved: Int
    let eligible: Int
    var value: Double? { eligible == 0 ? nil : Double(achieved) / Double(eligible) }
}

enum RetentionDataQualityStatus: String, Codable, Equatable, Sendable {
    case complete
    case partial
}

struct RetentionDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateCountsByEvent: [String: Int]
    let missingCount: Int
    let forbiddenCount: Int
    let unsupportedCount: Int
    let orphanCompletionCount: Int
    let preMeasurementCount: Int
    let futureCount: Int
}

struct RetentionScenarioExpectation: Equatable, Sendable {
    let requiredKeys: Set<String>
    let forbiddenKeys: Set<String>
}

struct RetentionScenarioValidation: Codable, Equatable, Sendable {
    let missingKeys: Set<String>
    let forbiddenKeys: Set<String>
}

struct RetentionReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let timeZoneIdentifier: String
    let reportingWeek: DateInterval
    let firstValue: RetentionRate
    let firstCompletion: RetentionRate
    let d1: RetentionRate
    let d7: RetentionRate
    let weeklyActiveInstallations: Int
    let weeklyRepeatedCompletion: RetentionRate
    let dataQuality: RetentionDataQuality
    let scenarioValidation: RetentionScenarioValidation
}
```

Use string keys in the encoded duplicate dictionary because `Codable` JSON keys must be strings.
Tests can compare `duplicateCountsByEvent[RetentionEventName.questCompleted.rawValue]`.

- [ ] **Step 5: Implement validation and canonicalization before metrics**

`RetentionReport.make` must perform these phases in order:

1. index installation snapshots by installation UUID and reject unsupported installation schemas;
2. count and exclude unsupported event schemas, event names, and sources;
3. count and exclude events before their installation's measurement start or after `asOf`;
4. group remaining rows by deduplication key;
5. select the earliest occurrence and then smallest UUID from each group;
6. count discarded duplicates by canonical event name;
7. compare canonical keys with `RetentionScenarioExpectation` when provided;
8. group canonical rows by installation and sort by occurrence time plus UUID;
9. identify first activation, first creation after activation, and first completion after creation;
10. classify a completion without a preceding creation as orphaned;
11. calculate D1/D7 by exact local calendar dates and right-censored eligible denominators;
12. calculate WAU and repeated completion from the explicit half-open reporting week;
13. set `.partial` when any quality or scenario count is nonzero.

Do not repair order, synthesize missing stages, or infer pre-measurement events.

- [ ] **Step 6: Implement deterministic Markdown rendering**

`renderMarkdown()` returns one sentence per line and includes:

- title and explicit synthetic-data warning;
- schema version, generated-at time, time zone, and week boundaries;
- a funnel section with `achieved / eligible` and a percentage or `N/A`;
- D1/D7 and weekly metrics;
- every data-quality count;
- scenario missing and forbidden counts;
- the exact single-worker reproduction command.

Format percentages with `Locale(identifier: "en_US_POSIX")` and one decimal place.
Sort dictionary keys before rendering so output is byte-for-byte stable.

- [ ] **Step 7: Run report tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionReportTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS with exact 3/4, 2/3, 2/4, 1/3, WAU 3, and repeat 1/3 results.

- [ ] **Step 8: Commit the pure report pipeline**

```bash
git add QuestKeeperShared/RetentionReport.swift QuestKeeperTests/RetentionReportTests.swift QuestKeeperTests/Fixtures/RetentionBaselineFixture.swift
git diff --cached --check
git commit -m "feat(metrics): calculate retention baseline"
```

---

### Task 4: Write The Live JSON Baseline On Genuine Activation

**Files:**

- Create: `QuestKeeperShared/RetentionBaselineStore.swift`
- Create: `QuestKeeper/Measurement/RetentionBaselineWriter.swift`
- Modify: `QuestKeeper/QuestKeeperApp.swift:10-91`
- Create: `QuestKeeperTests/RetentionBaselineStoreTests.swift`
- Modify: `QuestKeeperTests/QuestKeeperAppTests.swift:10-21`

**Interfaces:**

- Consumes: current `ModelContainer`, `RetentionEventRecorder`, `RetentionReport.make`, and App Group container URL.
- Produces: `RetentionBaselineStore.save`, `RetentionBaselineStore.load`, `RetentionBaselineWriter.recordActivationAndWrite`, and pure `shouldRecordRetentionActivation`.

- [ ] **Step 1: Write failing store tests**

Mirror the existing widget snapshot-store tests with a temporary file URL.
Require:

- `save` then `load` round-trips a complete report;
- sorted-key ISO-8601 JSON is byte-for-byte stable across two saves;
- saving through a nested missing directory creates it;
- a nil App Group URL throws `RetentionBaselineStoreError.appGroupUnavailable`;
- missing, corrupt, and unsupported-schema files load as `nil`;
- the encoded bytes do not contain a fixture quest title or the strings `vendorIdentifier`, `advertisingIdentifier`, `deviceName`, `email`, `location`, or `ipAddress`.

Before trusting the final privacy assertion, deliberately add a forbidden `questTitle` field to a local test-only encoded wrapper and observe the assertion fail once.
Remove that injected field, run the production report encoding, and require the assertion to pass.

- [ ] **Step 2: Implement the baseline store by matching the existing snapshot-store seam**

Create:

```swift
nonisolated enum RetentionBaselineStoreError: Error, Equatable {
    case appGroupUnavailable
}

nonisolated struct RetentionBaselineStore: Sendable {
    static let fileName = "retention-baseline-v1.json"

    init(
        appGroupIdentifier: String = WidgetDungeonSnapshotStore.appGroupIdentifier,
        fileManager: FileManager = .default
    )
    init(fileURL: URL?, fileManager: FileManager = .default)
    func load() -> RetentionReport?
    func save(_ report: RetentionReport) throws
}
```

Use an injected `FileManagerBox` matching `WidgetDungeonSnapshotStore`.
Encode dates as ISO-8601, use `.sortedKeys`, create the parent directory, and write with `.atomic`.
Return `nil` for a missing, corrupt, or unsupported-schema file.

- [ ] **Step 3: Write failing activation-gate tests**

Add a pure helper test matrix:

```swift
@Test(
    "retention activation records only initial launch and background return",
    arguments: [
        (false, false, true),
        (true, false, false),
        (true, true, true),
    ]
)
func retentionActivationGate(
    hasRecordedActivation: Bool,
    didBackground: Bool,
    expected: Bool
) {
    #expect(shouldRecordRetentionActivation(
        hasRecordedActivation: hasRecordedActivation,
        didBackground: didBackground
    ) == expected)
}
```

The helper must return false for inactive-to-active peeks after the initial activation.

- [ ] **Step 4: Implement the app-only writer**

Create `@MainActor final class RetentionBaselineWriter` with an injected store and this method:

```swift
func recordActivationAndWrite(
    sessionID: UUID,
    at now: Date,
    using container: ModelContainer,
    calendar: Calendar = .current
)
```

The method must:

1. call `RetentionEventRecorder.recordActivation` on `container.mainContext`;
2. save the context when it has changes so the activation is visible to the report fetch;
3. fetch every `RetentionInstallation` and `RetentionEvent` sorted by timestamp;
4. map them to snapshots;
5. calculate the calendar week containing `now` through `calendar.dateInterval(of: .weekOfYear, for: now)`;
6. call `RetentionReport.make` with no scenario expectation for the live report;
7. save the JSON through `RetentionBaselineStore`;
8. catch errors and log only the stage name plus error description.

Do not log event payloads, UUIDs, keys, or report JSON.

- [ ] **Step 5: Wire the activation owner without changing the existing refresh gate**

Add stable properties to `QuestKeeperApp`:

```swift
@State private var hasRecordedRetentionActivation = false
@State private var retentionActivationSessionID = UUID()
private let retentionBaselineWriter: RetentionBaselineWriter
```

Initialize the writer once in `init()`.
On `.background`, keep `didBackground = true` and assign a new session UUID.
On `.active`, capture whether the app had backgrounded before the existing container-refresh branch mutates `didBackground`.
Use this pure helper:

```swift
nonisolated func shouldRecordRetentionActivation(
    hasRecordedActivation: Bool,
    didBackground: Bool
) -> Bool {
    !hasRecordedActivation || didBackground
}
```

When it returns true, set `hasRecordedRetentionActivation = true` and invoke the writer with the same refreshed-or-current container passed to `syncActivation`.
Do not call the writer from `ContentView`.

- [ ] **Step 6: Run store and app-gate tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests/RetentionBaselineStoreTests -only-testing:QuestKeeperTests/QuestKeeperAppTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS; initial/background activations write while inactive peeks do not.

- [ ] **Step 7: Commit live baseline persistence**

```bash
git add QuestKeeperShared/RetentionBaselineStore.swift QuestKeeper/Measurement/RetentionBaselineWriter.swift QuestKeeper/QuestKeeperApp.swift QuestKeeperTests/RetentionBaselineStoreTests.swift QuestKeeperTests/QuestKeeperAppTests.swift
git diff --cached --check
git commit -m "feat(metrics): write live retention baseline"
```

---

### Task 5: Check In The Synthetic Baseline And Close AND-33 Verification

**Files:**

- Create: `docs/notes/012-retention-baseline.md`
- Modify: `QuestKeeperTests/RetentionReportTests.swift`
- Modify only if direct implementation evidence requires clarification: `docs/specs/012-core-retention-funnel.md`

**Interfaces:**

- Consumes: `RetentionBaselineFixture` and `RetentionReport.renderMarkdown()`.
- Produces: a checked-in report that the test suite proves is exactly reproducible.

- [ ] **Step 1: Generate the first synthetic baseline from the fixture**

Add a temporary test that prints `RetentionReport.make(...).renderMarkdown()` using the canonical fixture.
Run only that test, copy the exact printed body into `docs/notes/012-retention-baseline.md`, then replace the print with an equality assertion that reads the checked-in note relative to `#filePath`.

The permanent test must look like:

```swift
@Test("checked-in synthetic baseline matches the deterministic renderer")
func checkedInBaselineMatchesRenderer() throws {
    let report = RetentionReport.make(
        installations: RetentionBaselineFixture.installations,
        events: RetentionBaselineFixture.events,
        asOf: RetentionBaselineFixture.asOf,
        calendar: RetentionBaselineFixture.calendar,
        reportingWeek: RetentionBaselineFixture.reportingWeek,
        expectation: RetentionBaselineFixture.expectation
    )
    let noteURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "docs/notes/012-retention-baseline.md")

    #expect(try String(contentsOf: noteURL, encoding: .utf8) == report.renderMarkdown())
}
```

The note must explicitly say that its data is synthetic and is not evidence of real user performance.

- [ ] **Step 2: Run all focused measurement tests**

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:QuestKeeperTests/RetentionPersistenceTests \
  -only-testing:QuestKeeperTests/RetentionEventRecorderTests \
  -only-testing:QuestKeeperTests/RetentionReportTests \
  -only-testing:QuestKeeperTests/RetentionBaselineStoreTests \
  -only-testing:QuestKeeperTests/QuestStoreActorTests \
  -only-testing:QuestKeeperTests/QuestKeeperAppTests \
  -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
```

Expected: PASS with exact fixture metrics and byte-identical Markdown.

- [ ] **Step 3: Run the complete unit-test and build gates**

Run one heavy command at a time:

```bash
xcodebuild test -project QuestKeeper.xcodeproj -scheme QuestKeeper -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:QuestKeeperTests -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 -jobs 2
xcodebuild build -project QuestKeeper.xcodeproj -scheme QuestKeeperWidget -destination 'platform=iOS Simulator,name=iPhone 17e' -jobs 2
git diff --check
```

Expected: all `QuestKeeperTests` pass, the widget builds, and the diff check exits 0.

- [ ] **Step 4: Run persistence and privacy guards**

Verify that `Quest` remains unchanged from the base and that no dependency file changed:

```bash
git diff origin/main -- QuestKeeperShared/Quest.swift
git diff --name-only origin/main -- Package.swift Package.resolved Podfile Podfile.lock Cartfile Cartfile.resolved
git diff --check origin/main
```

Expected: the first two commands print nothing and the diff check exits 0.

Run a source-field guard limited to stored measurement models.
First verify the guard can fail by running it against a temporary copy containing one injected `var questTitle: String`; remove the temporary copy immediately after that expected failure.
Then run the same guard against `QuestKeeperShared/RetentionEvent.swift` and require no forbidden stored field.

- [ ] **Step 5: Perform the manual simulator and App Group report QA**

Use one iPhone 17e simulator and the app's real UI:

1. uninstall QuestKeeper to create a fresh measured installation;
2. build and run the app;
3. create `첫 가치 확인` and confirm it appears in the dungeon;
4. complete it in the app;
5. background and reactivate the app;
6. create `위젯 완료 확인`;
7. add or refresh the QuestKeeper widget and complete that quest from the widget;
8. reactivate the app;
9. resolve the App Group container path with `group_path=$(xcrun simctl get_app_container booted kr.donminzzi.QuestKeeper group.kr.donminzzi.QuestKeeper)`;
10. inspect `retention-baseline-v1.json` with `plutil -p` or `jq`;
11. confirm the report counts one first activation, one first value, the app completion, one background return, and the widget completion without duplicate credit;
12. search the JSON for both typed quest titles and require zero matches;
13. confirm app completion, widget completion, daily-grave, retry, and notification behavior still work as before.

Record the simulator name, OS version, build commit, observed JSON status, and any OS-controlled widget delay in a short evidence section appended to `docs/notes/012-retention-baseline.md` only if that section is rendered separately from the deterministic generated body.
If adding manual evidence would break the renderer equality, create `docs/notes/012-retention-verification.md` instead and keep the generated baseline byte-stable.

- [ ] **Step 6: Commit the reproducible baseline and direct verification note**

```bash
git add docs/notes/012-retention-baseline.md QuestKeeperTests/RetentionReportTests.swift
if [ -f docs/notes/012-retention-verification.md ]; then git add docs/notes/012-retention-verification.md; fi
git diff --cached --check
git commit -m "docs(metrics): record retention baseline"
```

- [ ] **Step 7: Reconcile the branch and Linear issue**

Confirm the branch contains only the planned commits and no unrelated files:

```bash
git status --short
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

Expected: clean status and only AND-33 schema, recorder, report, live baseline, tests, spec, plan, and notes.

Update AND-33 to Done only after all acceptance criteria pass.
Add a Linear comment with the final commit SHA, exact test count, widget build result, synthetic baseline path, live JSON filename, and any manual QA limitation.
Do not change AND-34 through AND-39; AND-33 completion will merely unblock their existing dependency relationship.

---

## Final Verification Checklist

- [ ] `Quest` is byte-identical to `origin/main`.
- [ ] A pre-populated legacy store opens with every quest preserved.
- [ ] The four event names and their canonical owners match Spec 012.
- [ ] Inactive peeks, edit, cancelled creation, missing quest, and stale widget completion emit nothing.
- [ ] Retry plus a new completion creates a distinct completion key.
- [ ] Exact duplicate, omission, forbidden, orphan, unsupported, pre-measurement, and future cases are tested.
- [ ] D1/D7 use exact local calendar dates and right-censored denominators.
- [ ] WAU and repeated completion use the explicit reporting week.
- [ ] The synthetic Markdown baseline is byte-identical to the renderer.
- [ ] The live JSON is atomic, schema-versioned, local-only, and free of user-entered text.
- [ ] All `QuestKeeperTests` pass with one worker.
- [ ] The widget target builds.
- [ ] The app and widget are manually exercised on iPhone 17e.
- [ ] The worktree is clean and Linear AND-33 contains final evidence before it moves to Done.
