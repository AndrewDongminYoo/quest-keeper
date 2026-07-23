import Darwin
import Foundation
import OSLog
import SwiftData

nonisolated struct RetentionInstallationIdentityStore: Sendable {
    let fileURL: URL

    static func appGroup() throws -> RetentionInstallationIdentityStore {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetDungeonSnapshotStore.appGroupIdentifier
        ) else {
            throw RetentionBaselineStoreError.appGroupUnavailable
        }
        return RetentionInstallationIdentityStore(
            fileURL: containerURL.appending(path: "retention-installation-id-v1")
        )
    }

    func loadOrCreate() throws -> UUID {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let lockURL = fileURL.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw posixError() }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw posixError() }
        defer { flock(descriptor, LOCK_UN) }

        if let data = try? Data(contentsOf: fileURL),
           let value = String(data: data, encoding: .utf8),
           let installationID = UUID(uuidString: value) {
            return installationID
        }

        let installationID = UUID()
        try Data(installationID.uuidString.utf8).write(to: fileURL, options: .atomic)
        return installationID
    }

    private func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

nonisolated enum RetentionRecordResult: Equatable, Sendable {
    case inserted
    case duplicate
    case failed
}

nonisolated struct RetentionRetryKeyMigrationMarkerStore: Sendable {
    static let fileExtension = "retry-key-migration-v1"

    let fileURL: URL

    var isCompleted: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func markCompleted() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: fileURL, options: .atomic)
    }
}

nonisolated enum RetentionEventRecorder {
    private static let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "RetentionMeasurement"
    )

    static func recordActivation(
        sessionID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .appActivated,
            source: .app,
            occurredAt: occurredAt,
            questID: nil,
            keyComponent: sessionID.uuidString,
            in: context
        )
    }

    static func recordQuestCreated(
        questID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCreated,
            source: .app,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: questID.uuidString,
            in: context
        )
    }

    static func recordQuestCompleted(
        questID: UUID,
        completedAt: Date,
        source: RetentionEventSource,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCompleted,
            source: source,
            occurredAt: completedAt,
            questID: questID,
            keyComponent: "\(questID.uuidString):\(completedAt.timeIntervalSinceReferenceDate.bitPattern)",
            in: context
        )
    }

    static func recordQuestRetried(
        questID: UUID,
        attemptID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questRetried,
            source: .app,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: "\(questID.uuidString):\(attemptID.uuidString)",
            in: context
        )
    }

    static func normalizeLegacyQuestRetryDeduplicationKeysIfNeeded(
        in context: ModelContext,
        markerStore: RetentionRetryKeyMigrationMarkerStore
    ) {
        guard !markerStore.isCompleted else { return }

        do {
            let retryName = RetentionEventName.questRetried.rawValue
            let descriptor = FetchDescriptor<RetentionEvent>(
                predicate: #Predicate { $0.nameRawValue == retryName }
            )
            let events = try context.fetch(descriptor)
            let legacyGroups = Dictionary(grouping: events.filter {
                retryAttemptID(in: $0, retryName: retryName) == nil
            }, by: \.deduplicationKey)

            for rows in legacyGroups.values {
                guard let replacementID = rows.map(\.id.uuidString).min() else { continue }
                for event in rows {
                    let questComponent = event.questID?.uuidString ?? "missing-quest"
                    event.deduplicationKey = [
                        retryName,
                        event.installationID.uuidString,
                        questComponent,
                        replacementID,
                    ].joined(separator: ":")
                }
            }

            if !legacyGroups.isEmpty {
                try context.save()
            }
            try markerStore.markCompleted()
        } catch {
            logger.error(
                "Failed to normalize legacy retry keys: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private static func retryAttemptID(
        in event: RetentionEvent,
        retryName: String
    ) -> UUID? {
        let questComponent = event.questID?.uuidString ?? "missing-quest"
        let prefix = "\(retryName):\(event.installationID.uuidString):\(questComponent):"
        guard event.deduplicationKey.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(event.deduplicationKey.dropFirst(prefix.count)))
    }

    static func recordExperimentExposed(
        experimentKey: String,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .experimentExposed,
            source: .app,
            occurredAt: occurredAt,
            questID: nil,
            keyComponent: experimentKey,
            in: context
        )
    }

    static func recordQuestCreationStarted(
        experimentKey: String,
        actionID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questCreationStarted,
            source: .app,
            occurredAt: occurredAt,
            questID: nil,
            keyComponent: "\(experimentKey):\(actionID)",
            in: context
        )
    }

    static func recordOnboardingDeferred(
        experimentKey: String,
        sessionID: UUID,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .onboardingDeferred,
            source: .app,
            occurredAt: occurredAt,
            questID: nil,
            keyComponent: "\(experimentKey):\(sessionID)",
            in: context
        )
    }

    private static func record(
        name: RetentionEventName,
        source: RetentionEventSource,
        occurredAt: Date,
        questID: UUID?,
        keyComponent: String,
        in context: ModelContext
    ) -> RetentionRecordResult {
        do {
            var installationDescriptor = FetchDescriptor<RetentionInstallation>(
                sortBy: [SortDescriptor(\.measurementStartedAt)]
            )
            installationDescriptor.fetchLimit = 1
            let installation: RetentionInstallation
            if let existing = try context.fetch(installationDescriptor).first {
                installation = existing
            } else {
                let installationID = try RetentionInstallationIdentityStore.appGroup().loadOrCreate()
                let created = RetentionInstallation(
                    installationID: installationID,
                    measurementStartedAt: occurredAt
                )
                context.insert(created)
                installation = created
            }

            let deduplicationKey = "\(name.rawValue):\(installation.installationID):\(keyComponent)"
            var eventDescriptor = FetchDescriptor<RetentionEvent>(
                predicate: #Predicate { $0.deduplicationKey == deduplicationKey }
            )
            eventDescriptor.fetchLimit = 1
            guard try context.fetch(eventDescriptor).isEmpty else { return .duplicate }

            context.insert(RetentionEvent(
                name: name,
                installationID: installation.installationID,
                occurredAt: occurredAt,
                source: source,
                questID: questID,
                deduplicationKey: deduplicationKey
            ))
            return .inserted
        } catch {
            logger.error("Failed to record \(name.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            return .failed
        }
    }
}
