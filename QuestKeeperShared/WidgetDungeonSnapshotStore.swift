import Foundation

nonisolated enum WidgetDungeonSnapshotStoreError: Error, Equatable {
    case appGroupUnavailable
}

/// Describes why the widget could not obtain a usable snapshot. Keeping this
/// information separate from an empty payload lets the widget distinguish a
/// genuinely quiet dungeon from a broken App Group or snapshot file.
nonisolated enum WidgetDungeonSnapshotLoadError: Error, Equatable {
    case appGroupUnavailable
    case snapshotMissing
    case unreadableSnapshot
    case unsupportedSchema(Int)
    case invalidQuestImportance(Int)
}

nonisolated struct WidgetDungeonSnapshotStore: Sendable {
    static let appGroupIdentifier = "group.kr.donminzzi.QuestKeeper"
    static let fileName = "widget-dungeon-snapshot.json"

    private let fileURL: URL?
    private let prepareDirectory: @Sendable (URL) throws -> Void
    private let fileExists: @Sendable (URL) -> Bool

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
        self.fileExists = { url in fileManagerBox.value.fileExists(atPath: url.path) }
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.init(fileURL: Optional(fileURL), fileManager: fileManager)
    }

    init(fileURL: URL?, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        let fileManagerBox = FileManagerBox(fileManager)
        self.prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
        self.fileExists = { url in fileManagerBox.value.fileExists(atPath: url.path) }
    }

    func load() -> WidgetDungeonPayload {
        (try? loadResult().get()) ?? .empty
    }

    func loadResult() -> Result<WidgetDungeonPayload, WidgetDungeonSnapshotLoadError> {
        guard let fileURL else { return .failure(.appGroupUnavailable) }

        guard fileExists(fileURL) else {
            return .failure(.snapshotMissing)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let versionEnvelope = try JSONDecoder.widgetDungeon.decode(
                WidgetDungeonSnapshotVersionEnvelope.self,
                from: data
            )
            guard versionEnvelope.schemaVersion == WidgetDungeonPayload.currentSchemaVersion else {
                return .failure(.unsupportedSchema(versionEnvelope.schemaVersion))
            }
            let payload = try JSONDecoder.widgetDungeon.decode(WidgetDungeonPayload.self, from: data)
            if let invalidImportance = payload.quests
                .map(\.importanceRawValue)
                .first(where: { Importance(rawValue: $0) == nil }) {
                return .failure(.invalidQuestImportance(invalidImportance))
            }
            return .success(payload)
        } catch {
            return .failure(.unreadableSnapshot)
        }
    }

    func save(_ payload: WidgetDungeonPayload) throws {
        guard let fileURL else {
            throw WidgetDungeonSnapshotStoreError.appGroupUnavailable
        }

        try prepareDirectory(fileURL.deletingLastPathComponent())

        let data = try JSONEncoder.widgetDungeon.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private nonisolated struct WidgetDungeonSnapshotVersionEnvelope: Decodable {
    let schemaVersion: Int
}

private nonisolated final class FileManagerBox: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}
