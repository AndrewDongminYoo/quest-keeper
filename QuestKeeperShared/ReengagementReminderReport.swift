import Foundation

nonisolated struct ReengagementReminderDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateCountsByEvent: [String: Int]
    let unsupportedCount: Int
    let futureCount: Int
}

nonisolated struct ReengagementReminderReport: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let timeZoneIdentifier: String
    let permissionGrantRate: RetentionRate
    let reminderDisableRate: RetentionRate
    let notificationCompletionRate: RetentionRate
    let dataQuality: ReengagementReminderDataQuality

    static func make(
        events: [RetentionEventSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> ReengagementReminderReport {
        var unsupportedCount = 0
        var futureCount = 0
        var validEvents: [RetentionEventSnapshot] = []
        for event in events {
            guard let name = event.name, name.isReengagement else { continue }
            guard event.schemaVersion == RetentionEvent.currentSchemaVersion,
                  let source = event.source,
                  isValidCombination(name: name, source: source, questID: event.questID) else {
                unsupportedCount += 1
                continue
            }
            guard event.occurredAt <= asOf else {
                futureCount += 1
                continue
            }
            validEvents.append(event)
        }

        var duplicateCountsByEvent: [String: Int] = [:]
        let canonicalEvents = Dictionary(grouping: validEvents, by: \.deduplicationKey)
            .compactMap { _, rows -> RetentionEventSnapshot? in
                let sorted = rows.sorted(by: eventOrdering)
                for duplicate in sorted.dropFirst() {
                    duplicateCountsByEvent[duplicate.nameRawValue, default: 0] += 1
                }
                return sorted.first
            }
            .sorted(by: eventOrdering)

        let permissionRequests = canonicalEvents.count { $0.name == .reengagementPermissionRequested }
        let permissionGrants = canonicalEvents.count { $0.name == .reengagementPermissionGranted }
        let reminderEnabled = canonicalEvents.count { $0.name == .reengagementReminderEnabled }
        let reminderDisabled = canonicalEvents.count { $0.name == .reengagementReminderDisabled }
        let notificationOpened = canonicalEvents.count { $0.name == .reengagementNotificationOpened }
        let notificationCompleted = canonicalEvents.count { $0.name == .reengagementNotificationCompleted }
        let dataQuality = ReengagementReminderDataQuality(
            status: duplicateCountsByEvent.isEmpty && unsupportedCount == 0 && futureCount == 0
                ? .complete
                : .partial,
            duplicateCountsByEvent: duplicateCountsByEvent,
            unsupportedCount: unsupportedCount,
            futureCount: futureCount
        )
        return ReengagementReminderReport(
            schemaVersion: currentSchemaVersion,
            generatedAt: asOf,
            timeZoneIdentifier: calendar.timeZone.identifier,
            permissionGrantRate: RetentionRate(achieved: permissionGrants, eligible: permissionRequests),
            reminderDisableRate: RetentionRate(achieved: reminderDisabled, eligible: reminderEnabled),
            notificationCompletionRate: RetentionRate(achieved: notificationCompleted, eligible: notificationOpened),
            dataQuality: dataQuality
        )
    }
}

nonisolated struct ReengagementReminderStore: Sendable {
    static let fileName = "reengagement-reminder-v1.json"

    private let fileURL: URL?
    private let prepareDirectory: @Sendable (URL) throws -> Void

    init(
        appGroupIdentifier: String = WidgetDungeonSnapshotStore.appGroupIdentifier,
        fileManager: FileManager = .default
    ) {
        let fileManagerBox = ReengagementFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
        fileURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: Self.fileName)
    }

    init(fileURL: URL?, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        let fileManagerBox = ReengagementFileManagerBox(fileManager)
        prepareDirectory = { url in
            try fileManagerBox.value.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func load() -> ReengagementReminderReport? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let report = try? JSONDecoder.retentionBaseline.decode(ReengagementReminderReport.self, from: data),
              report.schemaVersion == ReengagementReminderReport.currentSchemaVersion
        else { return nil }
        return report
    }

    func save(_ report: ReengagementReminderReport) throws {
        guard let fileURL else { throw RetentionBaselineStoreError.appGroupUnavailable }
        try prepareDirectory(fileURL.deletingLastPathComponent())
        let data = try JSONEncoder.retentionBaseline.encode(report)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private nonisolated func isValidCombination(
    name: RetentionEventName,
    source: RetentionEventSource,
    questID: UUID?
) -> Bool {
    switch name {
    case .reengagementPermissionRequested,
         .reengagementPermissionGranted,
         .reengagementPermissionDenied,
         .reengagementReminderEnabled,
         .reengagementReminderDisabled:
        source == .app && questID == nil
    case .reengagementNotificationOpened, .reengagementNotificationCompleted:
        source == .app && questID != nil
    default:
        false
    }
}

private nonisolated func eventOrdering(
    _ lhs: RetentionEventSnapshot,
    _ rhs: RetentionEventSnapshot
) -> Bool {
    if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
    return lhs.id.uuidString < rhs.id.uuidString
}

private nonisolated final class ReengagementFileManagerBox: @unchecked Sendable {
    let value: FileManager

    init(_ value: FileManager) {
        self.value = value
    }
}
