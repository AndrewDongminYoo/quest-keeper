import Foundation
import SwiftData

nonisolated enum RetentionEventName: String, Codable, CaseIterable, Sendable {
    case appActivated = "app_activated"
    case questCreated = "quest_created"
    case questCompleted = "quest_completed"
    case questRetried = "quest_retried"
    case experimentExposed = "experiment_exposed"
    case questCreationStarted = "quest_creation_started"
    case onboardingDeferred = "onboarding_deferred"
}

nonisolated enum RetentionEventSource: String, Codable, CaseIterable, Sendable {
    case app
    case widget
}

@Model
final class RetentionInstallation {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var installationID: UUID
    var measurementStartedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        installationID: UUID = UUID(),
        measurementStartedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.installationID = installationID
        self.measurementStartedAt = measurementStartedAt
    }

    var snapshot: RetentionInstallationSnapshot {
        RetentionInstallationSnapshot(
            schemaVersion: schemaVersion,
            installationID: installationID,
            measurementStartedAt: measurementStartedAt
        )
    }
}

@Model
final class RetentionEvent {
    static let currentSchemaVersion = 1

    var id: UUID
    var schemaVersion: Int
    var nameRawValue: String
    var installationID: UUID
    var occurredAt: Date
    var sourceRawValue: String
    var questID: UUID?
    var deduplicationKey: String

    init(
        id: UUID = UUID(),
        schemaVersion: Int = currentSchemaVersion,
        name: RetentionEventName,
        installationID: UUID,
        occurredAt: Date,
        source: RetentionEventSource,
        questID: UUID?,
        deduplicationKey: String
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.nameRawValue = name.rawValue
        self.installationID = installationID
        self.occurredAt = occurredAt
        self.sourceRawValue = source.rawValue
        self.questID = questID
        self.deduplicationKey = deduplicationKey
    }

    var snapshot: RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: id,
            schemaVersion: schemaVersion,
            nameRawValue: nameRawValue,
            installationID: installationID,
            occurredAt: occurredAt,
            sourceRawValue: sourceRawValue,
            questID: questID,
            deduplicationKey: deduplicationKey
        )
    }
}

nonisolated struct RetentionInstallationSnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let installationID: UUID
    let measurementStartedAt: Date
}

nonisolated struct RetentionEventSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let schemaVersion: Int
    let nameRawValue: String
    let installationID: UUID
    let occurredAt: Date
    let sourceRawValue: String
    let questID: UUID?
    let deduplicationKey: String

    var name: RetentionEventName? {
        RetentionEventName(rawValue: nameRawValue)
    }

    var source: RetentionEventSource? {
        RetentionEventSource(rawValue: sourceRawValue)
    }

    var experimentKeyComponent: String? {
        guard let name, name.isExperimentSpecific else { return nil }
        let prefix = "\(name.rawValue):\(installationID.uuidString):"
        guard deduplicationKey.hasPrefix(prefix) else { return nil }
        let component = deduplicationKey.dropFirst(prefix.count)
        switch name {
        case .experimentExposed:
            return component.isEmpty ? nil : String(component)
        case .questCreationStarted, .onboardingDeferred:
            return component.split(separator: ":", maxSplits: 1).first.map(String.init)
        default:
            return nil
        }
    }
}

extension RetentionEventName {
    nonisolated var isExperimentSpecific: Bool {
        self == .experimentExposed || self == .questCreationStarted || self == .onboardingDeferred
    }

    nonisolated var isOnboardingProgress: Bool {
        switch self {
        case .experimentExposed, .questCreationStarted, .questCreated, .questCompleted, .onboardingDeferred:
            true
        case .appActivated, .questRetried:
            false
        }
    }
}
