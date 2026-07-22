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

        container.mainContext.insert(quest)
        container.mainContext.insert(installation)
        container.mainContext.insert(event)
        container.mainContext.insert(assignment)
        try container.mainContext.save()

        #expect(try container.mainContext.fetch(FetchDescriptor<Quest>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionInstallation>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<RetentionEvent>()).count == 1)
        #expect(try container.mainContext.fetch(FetchDescriptor<ExperimentAssignment>()).count == 1)
        #expect(event.snapshot.nameRawValue == "quest_created")
        #expect(event.snapshot.sourceRawValue == "app")
        #expect(assignment.snapshot.variant == .guided)
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
    }

    private func measurementContainer() throws -> ModelContainer {
        let schema = Schema([
            Quest.self,
            RetentionInstallation.self,
            RetentionEvent.self,
            ExperimentAssignment.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
