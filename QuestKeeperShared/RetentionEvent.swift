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
    case reengagementPermissionRequested = "reengagement_permission_requested"
    case reengagementPermissionGranted = "reengagement_permission_granted"
    case reengagementPermissionDenied = "reengagement_permission_denied"
    case reengagementReminderEnabled = "reengagement_reminder_enabled"
    case reengagementReminderDisabled = "reengagement_reminder_disabled"
    case reengagementNotificationOpened = "reengagement_notification_opened"
    case reengagementNotificationCompleted = "reengagement_notification_completed"
}

nonisolated enum RetentionEventSource: String, Codable, CaseIterable, Sendable {
    case app
    case widget
    case shortcut
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
        case .appActivated,
             .questRetried,
             .reengagementPermissionRequested,
             .reengagementPermissionGranted,
             .reengagementPermissionDenied,
             .reengagementReminderEnabled,
             .reengagementReminderDisabled,
             .reengagementNotificationOpened,
             .reengagementNotificationCompleted:
            false
        }
    }

    nonisolated var isReengagement: Bool {
        switch self {
        case .reengagementPermissionRequested,
             .reengagementPermissionGranted,
             .reengagementPermissionDenied,
             .reengagementReminderEnabled,
             .reengagementReminderDisabled,
             .reengagementNotificationOpened,
             .reengagementNotificationCompleted:
            true
        default:
            false
        }
    }
}

extension RetentionEventSnapshot {
    /// 스펙 012가 정의한 첫 가치 경험의 사실: 유효하게 기록된 `quest_created`.
    ///
    /// 현재 퀘스트 목록이 아니라 이 사실을 읽기 때문에, 사용자가 퀘스트를 모두 지워도 경계는 다시 닫히지 않는다.
    /// 유효 조합은 `RetentionReport`가 `.questCreated`에 적용하는 것과 같게 손으로 맞춰 두었다. 그쪽을 고칠 때 여기도 함께 봐야 한다.
    nonisolated var isFirstValueQuestCreation: Bool {
        guard schemaVersion == RetentionEvent.currentSchemaVersion,
              name == .questCreated,
              let source else {
            return false
        }
        // `RetentionReport`의 `.questCreated` 유효 조합과 같은 조건이다. 한쪽만 고치면 두 곳이 조용히 어긋난다.
        return (source == .app || source == .shortcut) && questID != nil
    }
}
