import Foundation

nonisolated struct WidgetDungeonSnapshotStore: Sendable {
    static let appGroupIdentifier = "group.kr.donminzzi.QuestKeeper"
    static let fileName = "widget-dungeon-snapshot.json"

    private let fileURL: URL?
    private let prepareDirectory: @Sendable (URL) throws -> Void

    init(
        appGroupIdentifier: String = Self.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        let fileManagerBox = FileManagerBox(fileManager)
        self.prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        let fileManagerBox = FileManagerBox(fileManager)
        self.prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
    }

    func load() -> WidgetDungeonPayload {
        guard let fileURL else { return .empty }

        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try JSONDecoder.widgetDungeon.decode(WidgetDungeonPayload.self, from: data)
            guard payload.schemaVersion == WidgetDungeonPayload.currentSchemaVersion else {
                return .empty
            }
            return payload
        } catch {
            return .empty
        }
    }

    func save(_ payload: WidgetDungeonPayload) throws {
        guard let fileURL else { return }

        try prepareDirectory(fileURL.deletingLastPathComponent())

        let data = try JSONEncoder.widgetDungeon.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private nonisolated final class FileManagerBox: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}
