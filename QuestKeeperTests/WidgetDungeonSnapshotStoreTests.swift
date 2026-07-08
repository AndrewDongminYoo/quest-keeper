import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon snapshot store")
struct WidgetDungeonSnapshotStoreTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("store saves and loads payload atomically")
    func storeSavesAndLoadsPayload() throws {
        let directory = temporaryDirectory()
        let store = WidgetDungeonSnapshotStore(
            fileURL: directory.appending(path: "widget-dungeon-snapshot.json")
        )
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: [
                WidgetQuestPayload(
                    id: UUID(),
                    title: "위젯 확인",
                    deadline: now.addingTimeInterval(600),
                    completedAt: nil,
                    importanceRawValue: 2
                )
            ]
        )

        try store.save(payload)

        #expect(store.load() == payload)
    }

    @Test("store returns empty payload for missing file")
    func storeReturnsEmptyPayloadForMissingFile() {
        let directory = temporaryDirectory()
        let store = WidgetDungeonSnapshotStore(
            fileURL: directory.appending(path: "missing.json")
        )

        #expect(store.load() == .empty)
    }

    @Test("store returns empty payload for corrupt file")
    func storeReturnsEmptyPayloadForCorruptFile() throws {
        let directory = temporaryDirectory()
        let fileURL = directory.appending(path: "widget-dungeon-snapshot.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = WidgetDungeonSnapshotStore(fileURL: fileURL)

        #expect(store.load() == .empty)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "QuestKeeper-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
