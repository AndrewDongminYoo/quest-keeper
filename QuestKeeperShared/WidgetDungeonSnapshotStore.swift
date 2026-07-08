import Foundation

nonisolated struct WidgetDungeonSnapshotStore: Sendable {
    static let appGroupIdentifier = "group.kr.donminzzi.QuestKeeper"
    static let fileName = "widget-dungeon-snapshot.json"

    private let fileURL: URL?

    init(
        appGroupIdentifier: String = Self.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL, fileManager _: FileManager = .default) {
        self.fileURL = fileURL
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

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder.widgetDungeon.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }
}
