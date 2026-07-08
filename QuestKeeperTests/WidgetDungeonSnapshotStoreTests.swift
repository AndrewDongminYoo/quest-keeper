import Foundation
import Testing
@testable import QuestKeeper

@Suite("Widget dungeon snapshot store")
struct WidgetDungeonSnapshotStoreTests {
    private let now = Date(timeIntervalSinceReferenceDate: 820_454_400)

    @Test("store saves and loads payload")
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

    @Test("store uses injected file manager for save preparation")
    func storeUsesInjectedFileManagerForSavePreparation() throws {
        let fileManager = TrackingFileManager()
        let directory = temporaryDirectory()
        let fileURL = directory
            .appending(path: "nested", directoryHint: .isDirectory)
            .appending(path: "widget-dungeon-snapshot.json")
        let store = WidgetDungeonSnapshotStore(fileURL: fileURL, fileManager: fileManager)
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: []
        )

        try store.save(payload)

        #expect(fileManager.createdDirectories == [fileURL.deletingLastPathComponent()])
    }

    @Test("store save throws when app group container is unavailable")
    func storeSaveThrowsWhenAppGroupContainerIsUnavailable() {
        let store = WidgetDungeonSnapshotStore(fileURL: nil)
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion,
            generatedAt: now,
            quests: []
        )

        #expect(throws: WidgetDungeonSnapshotStoreError.appGroupUnavailable) {
            try store.save(payload)
        }
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

    @Test("store returns empty payload for unsupported schema")
    func storeReturnsEmptyPayloadForUnsupportedSchema() throws {
        let directory = temporaryDirectory()
        let fileURL = directory.appending(path: "widget-dungeon-snapshot.json")
        let payload = WidgetDungeonPayload(
            schemaVersion: WidgetDungeonPayload.currentSchemaVersion + 1,
            generatedAt: now,
            quests: []
        )

        try JSONEncoder.widgetDungeon.encode(payload).write(to: fileURL)

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

private final class TrackingFileManager: FileManager {
    var createdDirectories: [URL] = []

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey : Any]? = nil
    ) throws {
        createdDirectories.append(url)
        try super.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes
        )
    }
}
