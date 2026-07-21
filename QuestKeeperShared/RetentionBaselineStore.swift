import Foundation

nonisolated enum RetentionBaselineStoreError: Error, Equatable {
    case appGroupUnavailable
}

nonisolated struct RetentionBaselineStore: Sendable {
    static let fileName = "retention-baseline-v1.json"

    private let fileURL: URL?
    private let prepareDirectory: @Sendable (URL) throws -> Void

    init(
        appGroupIdentifier: String = WidgetDungeonSnapshotStore.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        let fileManagerBox = RetentionFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL?, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        let fileManagerBox = RetentionFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func load() -> RetentionReport? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let report = try? JSONDecoder.retentionBaseline.decode(RetentionReport.self, from: data),
              report.schemaVersion == RetentionReport.currentSchemaVersion
        else { return nil }
        return report
    }

    func save(_ report: RetentionReport) throws {
        guard let fileURL else { throw RetentionBaselineStoreError.appGroupUnavailable }
        try prepareDirectory(fileURL.deletingLastPathComponent())
        let data = try JSONEncoder.retentionBaseline.encode(report)
        try data.write(to: fileURL, options: [.atomic])
    }
}

nonisolated extension JSONEncoder {
    static var retentionBaseline: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

nonisolated extension JSONDecoder {
    static var retentionBaseline: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private nonisolated final class RetentionFileManagerBox: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}
