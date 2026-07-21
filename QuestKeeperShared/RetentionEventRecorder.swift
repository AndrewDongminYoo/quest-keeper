import Foundation
import OSLog
import SwiftData

nonisolated enum RetentionRecordResult: Equatable, Sendable {
    case inserted
    case duplicate
    case failed
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
        newDeadline: Date,
        at occurredAt: Date,
        in context: ModelContext
    ) -> RetentionRecordResult {
        record(
            name: .questRetried,
            source: .app,
            occurredAt: occurredAt,
            questID: questID,
            keyComponent: "\(questID.uuidString):\(newDeadline.timeIntervalSinceReferenceDate.bitPattern)",
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
                let created = RetentionInstallation(measurementStartedAt: occurredAt)
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
