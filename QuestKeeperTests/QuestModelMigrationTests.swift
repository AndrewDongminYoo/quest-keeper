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
    @Test("the in-memory fallback container actually accepts and returns facts")
    func ephemeralFallbackIsUsable() throws {
        // The fallback only earns its place if the app can keep running on it. A container that
        // constructs but rejects writes would trade a launch crash for a dead board.
        let container = QuestModelContainer.makeEphemeralFallback()
        let context = ModelContext(container)
        context.insert(Quest(title: "임시", deadline: .now, importance: .medium))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Quest>()).count == 1)
    }

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
        #expect(try current.mainContext.fetch(FetchDescriptor<RoutineRule>()).isEmpty)
        #expect(try current.mainContext.fetch(FetchDescriptor<RoutineCompletion>()).isEmpty)
    }

    @Test("a second container for the same store URL opens while the first is still held")
    func secondContainerForTheSameStoreOpens() throws {
        // `QuestShortcutCreationCoordinator` reopens the store while the app's container is still
        // held, and `QuestKeeperApp` does the same across the `.active` swap. A project note claimed
        // until 2026-09-01 that a second container for one store URL traps in SwiftData; the claim
        // was withdrawn as a blanket rule, and this is the standing gate for it. A trap fails the
        // run loudly instead of the shape being assumed safe.
        //
        // This says nothing about cross-process visibility: two containers in one process share the
        // coordinator's cache, so the fetch below is not evidence that a separate process would see
        // the write. That property has no gate in this suite — see issue #65.
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "store.sqlite")
        let markerURL = directory.appending(path: "retry-migration-marker")
        let id = UUID()

        let first = try QuestModelContainer.make(
            storeURL: storeURL,
            retryKeyMigrationMarkerURL: markerURL
        )
        first.mainContext.insert(Quest(
            id: id,
            title: "이미 있던 퀘스트",
            deadline: Date(timeIntervalSinceReferenceDate: 800_000_000),
            importance: .medium
        ))
        try first.mainContext.save()

        // The retry-key normalization runs on every open, so the second one exercises it against a
        // marker the first already wrote.
        let second = try QuestModelContainer.make(
            storeURL: storeURL,
            retryKeyMigrationMarkerURL: markerURL
        )

        #expect(try second.mainContext.fetch(FetchDescriptor<Quest>()).map(\.id) == [id])
        // Read through the first as well, so it is still referenced here: releasing it before
        // opening the second would not exercise the overlap the shortcut path relies on.
        #expect(try first.mainContext.fetchCount(FetchDescriptor<Quest>()) == 1)
    }
}
