import Foundation

nonisolated struct ReengagementReminderDataQuality: Codable, Equatable, Sendable {
    let status: RetentionDataQualityStatus
    let duplicateCountsByEvent: [String: Int]
    let unsupportedCount: Int
    let futureCount: Int
    /// Successors with no matching predecessor, keyed by the successor's event name. They are
    /// excluded from every numerator, so without this count a lost predecessor would silently
    /// shrink a rate instead of reporting itself.
    let orphanCountsByEvent: [String: Int]
}

/// How a successor event is linked back to the predecessor that makes it eligible.
private nonisolated enum ReengagementPairLink {
    /// One user action recorded both, so they carry the same action ID — and, for the notification
    /// pair, the same quest.
    case actionID(matchesQuestID: Bool)
    /// Separate user actions days apart, each minting its own action ID. Any earlier predecessor
    /// from the same installation is the strongest link the recorded facts support.
    case anyEarlier
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

        // A successor without its predecessor is not evidence of the thing the rate measures, and
        // counting the kinds independently lets one produce `achieved = 1, eligible = 0`.
        var orphanCountsByEvent: [String: Int] = [:]
        func matched(
            _ predecessor: RetentionEventName,
            _ successor: RetentionEventName,
            _ link: ReengagementPairLink
        ) -> Int {
            let counts = pairCounts(
                in: canonicalEvents,
                predecessor: predecessor,
                successor: successor,
                link: link
            )
            if counts.orphaned > 0 {
                orphanCountsByEvent[successor.rawValue, default: 0] += counts.orphaned
            }
            return counts.matched
        }

        let permissionRequests = canonicalEvents.count { $0.name == .reengagementPermissionRequested }
        let permissionGrants = matched(
            .reengagementPermissionRequested,
            .reengagementPermissionGranted,
            .actionID(matchesQuestID: false)
        )
        // Denied feeds no rate, but it is the same recorded action and the same loss, so an orphan
        // there is the same data-quality signal as one on granted.
        _ = matched(
            .reengagementPermissionRequested,
            .reengagementPermissionDenied,
            .actionID(matchesQuestID: false)
        )
        let reminderEnabled = canonicalEvents.count { $0.name == .reengagementReminderEnabled }
        let reminderDisabled = matched(
            .reengagementReminderEnabled,
            .reengagementReminderDisabled,
            .anyEarlier
        )
        let notificationOpened = canonicalEvents.count { $0.name == .reengagementNotificationOpened }
        let notificationCompleted = matched(
            .reengagementNotificationOpened,
            .reengagementNotificationCompleted,
            .actionID(matchesQuestID: true)
        )
        let dataQuality = ReengagementReminderDataQuality(
            status: duplicateCountsByEvent.isEmpty && unsupportedCount == 0 && futureCount == 0
                && orphanCountsByEvent.isEmpty
                ? .complete
                : .partial,
            duplicateCountsByEvent: duplicateCountsByEvent,
            unsupportedCount: unsupportedCount,
            futureCount: futureCount,
            orphanCountsByEvent: orphanCountsByEvent
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

/// `make` pools installations rather than grouping by them, unlike `RetentionReport`, so the match
/// key always carries `installationID` instead of relying on an enclosing per-installation loop.
///
/// Each predecessor is consumed by at most one successor. Letting a single enable satisfy every
/// later disable would hide exactly the loss this counting exists to find: `enable → disable →
/// disable` would report two matched disables and leave the status `.complete`, even though the
/// second cycle's enable was never recorded.
///
/// The pool is per call, so it is not shared between the two permission outcomes and one request
/// could in principle satisfy both a grant and a denial. `saveReengagementSettings` switches on the
/// resolved authorization and records exactly one of them per request, so the recorder cannot write
/// that shape.
///
/// One forward pass, so "earlier" means earlier in the `eventOrdering` sort — events sharing an
/// instant stay deterministic, the same rule `RetentionReport` uses for orphan completions.
private nonisolated func pairCounts(
    in ordered: [RetentionEventSnapshot],
    predecessor: RetentionEventName,
    successor: RetentionEventName,
    link: ReengagementPairLink
) -> (matched: Int, orphaned: Int) {
    var available: [String: Int] = [:]
    var matched = 0
    var orphaned = 0
    for event in ordered where event.name == predecessor || event.name == successor {
        guard let key = matchKey(for: event, link: link) else {
            // An unparseable key cannot link anything. A predecessor simply goes unregistered,
            // which correctly leaves its successor without one.
            if event.name == successor { orphaned += 1 }
            continue
        }
        if event.name == predecessor {
            available[key, default: 0] += 1
        } else if let remaining = available[key], remaining > 0 {
            available[key] = remaining - 1
            matched += 1
        } else {
            orphaned += 1
        }
    }
    return (matched, orphaned)
}

private nonisolated func matchKey(
    for event: RetentionEventSnapshot,
    link: ReengagementPairLink
) -> String? {
    switch link {
    case .anyEarlier:
        return event.installationID.uuidString
    case .actionID(let matchesQuestID):
        guard let action = RetentionEventRecorder
            .actionIDComponent(of: event.deduplicationKey) else { return nil }
        let quest = matchesQuestID ? (event.questID?.uuidString ?? "") : ""
        return "\(event.installationID.uuidString):\(quest):\(action)"
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
