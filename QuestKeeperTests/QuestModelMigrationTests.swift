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
