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
        let assignment = ExperimentAssignment(
            installationID: installationID,
            variant: .guided,
            assignedAt: startedAt
        )
        let selection = DailyFocusSelection(
            installationID: installationID,
            localDayKey: "2026-05-08",
            timeZoneIdentifier: "Asia/Seoul",
            selectedQuestIDsData: try JSONEncoder().encode([questID.uuidString]),
            recordedAt: startedAt,
            kind: .confirmation
        )

        container.mainContext.insert(quest)
        container.mainContext.insert(installation)
        container.mainContext.insert(event)
        container.mainContext.insert(assignment)
        container.mainContext.insert(selection)
        try container.mainContext.save()

        #expect(try container.mainContext.fetch(FetchDescriptor<Quest>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionEvent>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<DailyFocusSelection>()).count == 1)
        #expect(event.snapshot.nameRawValue == "quest_created")
        #expect(event.snapshot.sourceRawValue == "app")
        #expect(assignment.snapshot.variant == .guided)
        #expect(selection.snapshot.selectedQuestIDs == [questID])
    }

    @Test("assignment snapshot exposes only approved experiment fields")
    func assignmentSnapshotHasApprovedShape() {
        let snapshot = ExperimentAssignmentSnapshot(
            schemaVersion: 1,
            experimentKey: OnboardingExperiment.key,
            installationID: installationID,
            variantRawValue: OnboardingExperimentVariant.control.rawValue,
            assignedAt: startedAt
        )

        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))
        #expect(labels == [
            "schemaVersion", "experimentKey", "installationID", "variantRawValue", "assignedAt",
        ])
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

    @Test("daily focus snapshot exposes only approved selection fields")
    func dailyFocusSnapshotHasApprovedShape() throws {
        let snapshot = DailyFocusSelectionSnapshot(
            id: eventID,
            schemaVersion: 1,
            installationID: installationID,
            localDayKey: "2026-05-08",
            timeZoneIdentifier: "Asia/Seoul",
            selectedQuestIDsData: try JSONEncoder().encode([questID.uuidString]),
            recordedAt: startedAt,
            kindRawValue: DailyFocusSelectionKind.confirmation.rawValue
        )

        let labels = Set(Mirror(reflecting: snapshot).children.compactMap(\.label))
        #expect(labels == [
            "id", "schemaVersion", "installationID", "localDayKey", "timeZoneIdentifier",
            "selectedQuestIDsData", "recordedAt", "kindRawValue",
        ])
    }

    @Test("adding measurement models preserves a pre-populated Quest store")
    func addingModelsPreservesExistingStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-retention-\(UUID().uuidString).store")
        let existingQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!

        do {
            let legacySchema = Schema([Quest.self])
            let legacyConfiguration = ModelConfiguration(schema: legacySchema, url: storeURL)
            let legacy = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
            legacy.mainContext.insert(Quest(
                id: existingQuestID,
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
        #expect(quests.first?.id == existingQuestID)
        #expect(quests.first?.title == "기존 퀘스트")
        #expect(quests.first?.deadline == startedAt.addingTimeInterval(7200))
        #expect(quests.first?.completedAt == startedAt.addingTimeInterval(60))
        #expect(quests.first?.importance == .high)
        #expect(try upgraded.mainContext.fetch(FetchDescriptor<RetentionEvent>()).isEmpty)
        #expect(try upgraded.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).isEmpty)
        #expect(try upgraded.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).isEmpty)
        #expect(try upgraded.mainContext.fetch(FetchDescriptor<DailyFocusSelection>()).isEmpty)
    }

    @Test("opening the shared store removes legacy deadline-bearing retry keys")
    func openingStoreNormalizesLegacyRetryKeys() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-retry-key-\(UUID().uuidString).store")
        let firstEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let secondEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let duplicateEventID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
        let firstDeadlineBits = startedAt.addingTimeInterval(86_400)
            .timeIntervalSinceReferenceDate.bitPattern
        let secondDeadlineBits = startedAt.addingTimeInterval(172_800)
            .timeIntervalSinceReferenceDate.bitPattern
        let firstLegacyKey = "quest_retried:\(installationID):\(questID):\(firstDeadlineBits)"
        let secondLegacyKey = "quest_retried:\(installationID):\(questID):\(secondDeadlineBits)"

        do {
            let legacy = try measurementContainer(storeURL: storeURL)
            legacy.mainContext.insert(RetentionInstallation(
                installationID: installationID,
                measurementStartedAt: startedAt
            ))
            legacy.mainContext.insert(RetentionEvent(
                id: firstEventID,
                name: .questRetried,
                installationID: installationID,
                occurredAt: startedAt,
                source: .app,
                questID: questID,
                deduplicationKey: firstLegacyKey
            ))
            legacy.mainContext.insert(RetentionEvent(
                id: secondEventID,
                name: .questRetried,
                installationID: installationID,
                occurredAt: startedAt.addingTimeInterval(86_400),
                source: .app,
                questID: questID,
                deduplicationKey: secondLegacyKey
            ))
            legacy.mainContext.insert(RetentionEvent(
                id: duplicateEventID,
                name: .questRetried,
                installationID: installationID,
                occurredAt: startedAt.addingTimeInterval(1),
                source: .app,
                questID: questID,
                deduplicationKey: firstLegacyKey
            ))
            try legacy.mainContext.save()
        }

        let upgraded = try QuestModelContainer.make(storeURL: storeURL)
        let events = try upgraded.mainContext.fetch(FetchDescriptor<RetentionEvent>())

        let keysByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0.deduplicationKey) })
        #expect(keysByID[firstEventID] == keysByID[duplicateEventID])
        #expect(keysByID[firstEventID] == "quest_retried:\(installationID):\(questID):\(firstEventID)")
        #expect(keysByID[secondEventID] == "quest_retried:\(installationID):\(questID):\(secondEventID)")
        #expect(FileManager.default.fileExists(
            atPath: storeURL.appendingPathExtension(
                RetentionRetryKeyMigrationMarkerStore.fileExtension
            ).path
        ))
    }

    @Test("retry-key cleanup failure does not block opening the shared store")
    func retryKeyCleanupFailureDoesNotBlockStore() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-retry-key-failure-\(UUID().uuidString).store")

        do {
            let legacy = try measurementContainer(storeURL: storeURL)
            legacy.mainContext.insert(RetentionInstallation(
                installationID: installationID,
                measurementStartedAt: startedAt
            ))
            try legacy.mainContext.save()
        }

        let opened = try QuestModelContainer.make(
            storeURL: storeURL,
            retryKeyMigrationMarkerURL: URL(filePath: "/dev/null/retry-key-migration")
        )

        #expect(try opened.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
    }

    private func measurementContainer() throws -> ModelContainer {
        try measurementContainer(
            configuration: ModelConfiguration(
                schema: measurementSchema,
                isStoredInMemoryOnly: true
            )
        )
    }

    private func measurementContainer(storeURL: URL) throws -> ModelContainer {
        try measurementContainer(
            configuration: ModelConfiguration(schema: measurementSchema, url: storeURL)
        )
    }

    private var measurementSchema: Schema {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
            DailyFocusSelection.self,
        ])
        return schema
    }

    private func measurementContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        let schema = measurementSchema
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
