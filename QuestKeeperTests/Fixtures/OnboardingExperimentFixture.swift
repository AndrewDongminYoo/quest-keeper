import Foundation
@testable import QuestKeeper

enum OnboardingExperimentFixture {
    static let timeZone = TimeZone(identifier: "Asia/Seoul")!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        return value
    }

    static let cohort = DateInterval(
        start: date("2026-07-01T15:00:00Z"),
        end: date("2026-07-08T15:00:00Z")
    )
    static let asOf = date("2026-07-12T15:00:00Z")

    static let controlA = uuid(1)
    static let controlB = uuid(2)
    static let guidedA = uuid(3)
    static let guidedB = uuid(4)
    static let controlQuest = uuid(101)
    static let guidedQuestA = uuid(103)
    static let guidedQuestB = uuid(104)

    static let assignments = [
        assignment(controlA, .control, "2026-07-01T15:00:00Z"),
        assignment(controlB, .control, "2026-07-06T15:00:00Z"),
        assignment(guidedA, .guided, "2026-07-01T15:00:00Z"),
        assignment(guidedB, .guided, "2026-07-06T15:00:00Z"),
    ]

    static let installations = assignments.map {
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: $0.installationID,
            measurementStartedAt: $0.assignedAt
        )
    }

    static let events = [
        event(1, .experimentExposed, controlA, "2026-07-01T15:00:00Z"),
        event(2, .questCreationStarted, controlA, "2026-07-01T15:00:10Z"),
        event(3, .questCreated, controlA, "2026-07-01T15:01:00Z", controlQuest),
        event(4, .questCompleted, controlA, "2026-07-01T15:05:00Z", controlQuest),
        event(5, .appActivated, controlA, "2026-07-02T16:00:00Z"),
        event(6, .appActivated, controlA, "2026-07-08T16:00:00Z"),
        event(7, .experimentExposed, controlB, "2026-07-06T15:00:00Z"),
        event(8, .questCreationStarted, controlB, "2026-07-06T15:00:10Z"),
        event(9, .experimentExposed, guidedA, "2026-07-01T15:00:00Z"),
        event(10, .questCreationStarted, guidedA, "2026-07-01T15:00:10Z"),
        event(11, .questCreated, guidedA, "2026-07-01T15:01:00Z", guidedQuestA),
        event(12, .questCompleted, guidedA, "2026-07-01T15:01:40Z", guidedQuestA),
        event(13, .appActivated, guidedA, "2026-07-02T16:00:00Z"),
        event(14, .experimentExposed, guidedB, "2026-07-06T15:00:00Z"),
        event(15, .questCreationStarted, guidedB, "2026-07-06T15:00:10Z"),
        event(16, .onboardingDeferred, guidedB, "2026-07-06T15:00:20Z"),
        event(17, .questCreated, guidedB, "2026-07-06T15:03:00Z", guidedQuestB),
    ]

    static let expectedControlFunnel = OnboardingExperimentFunnel(
        exposed: 2,
        creationStarted: 2,
        firstValue: 1,
        firstCompletion: 1
    )
    static let expectedGuidedFunnel = OnboardingExperimentFunnel(
        exposed: 2,
        creationStarted: 2,
        firstValue: 2,
        firstCompletion: 1
    )

    static func assignment(
        _ installationID: UUID,
        _ variant: OnboardingExperimentVariant,
        _ assignedAt: String,
        schemaVersion: Int = 1,
        experimentKey: String = OnboardingExperiment.key
    ) -> ExperimentAssignmentSnapshot {
        ExperimentAssignmentSnapshot(
            schemaVersion: schemaVersion,
            experimentKey: experimentKey,
            installationID: installationID,
            variantRawValue: variant.rawValue,
            assignedAt: date(assignedAt)
        )
    }

    static func event(
        _ id: Int,
        _ name: RetentionEventName,
        _ installationID: UUID,
        _ occurredAt: String,
        _ questID: UUID? = nil,
        source: RetentionEventSource = .app,
        key: String? = nil,
        schemaVersion: Int = 1
    ) -> RetentionEventSnapshot {
        let defaultComponent: String
        switch name {
        case .experimentExposed:
            defaultComponent = OnboardingExperiment.key
        case .questCreationStarted, .onboardingDeferred:
            defaultComponent = "\(OnboardingExperiment.key):\(id)"
        default:
            defaultComponent = String(id)
        }
        return RetentionEventSnapshot(
            id: uuid(1_000 + id),
            schemaVersion: schemaVersion,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: date(occurredAt),
            sourceRawValue: source.rawValue,
            questID: questID,
            deduplicationKey: key
                ?? "\(name.rawValue):\(installationID.uuidString):\(defaultComponent)"
        )
    }

    static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}
