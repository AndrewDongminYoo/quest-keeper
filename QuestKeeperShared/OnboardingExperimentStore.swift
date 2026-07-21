import Foundation

nonisolated struct OnboardingExperimentStore: Sendable {
    static let fileName = "onboarding-experiment-v1.json"

    private let fileURL: URL?
    private let prepareDirectory: @Sendable (URL) throws -> Void

    init(
        appGroupIdentifier: String = WidgetDungeonSnapshotStore.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        let fileManagerBox = OnboardingFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL?, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        let fileManagerBox = OnboardingFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func load() -> OnboardingExperimentReport? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let report = try? JSONDecoder.retentionBaseline.decode(
                  OnboardingExperimentReport.self,
                  from: data
              ),
              report.schemaVersion == OnboardingExperimentReport.currentSchemaVersion
        else { return nil }
        return report
    }

    func save(_ report: OnboardingExperimentReport) throws {
        guard let fileURL else { throw RetentionBaselineStoreError.appGroupUnavailable }
        try prepareDirectory(fileURL.deletingLastPathComponent())
        let data = try JSONEncoder.retentionBaseline.encode(report)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private nonisolated final class OnboardingFileManagerBox: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}
