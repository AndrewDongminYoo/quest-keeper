import Foundation
@testable import QuestKeeper

enum RetentionBaselineFixture {
    static let version = 1
    static let timeZone = TimeZone(identifier: "Asia/Seoul")!
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = timeZone
        value.firstWeekday = 2
        return value
    }

    static let asOf = date("2026-07-13T15:00:00Z")
    static let reportingWeek = DateInterval(
        start: date("2026-07-05T15:00:00Z"),
        end: date("2026-07-12T15:00:00Z")
    )

    static let installationA = uuid(1)
    static let installationB = uuid(2)
    static let installationC = uuid(3)
    static let installationD = uuid(4)
    static let questA = uuid(101)
    static let questB = uuid(102)
    static let questD = uuid(104)

    static let installations = [
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationA,
            measurementStartedAt: date("2026-06-30T15:00:00Z")
        ),
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationB,
            measurementStartedAt: date("2026-07-01T15:00:00Z")
        ),
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationC,
            measurementStartedAt: date("2026-07-02T15:00:00Z")
        ),
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationD,
            measurementStartedAt: date("2026-07-11T15:00:00Z")
        ),
    ]

    static let events = [
        event(1, "a-activation-0", .appActivated, installationA, "2026-06-30T15:00:00Z"),
        event(2, "a-created", .questCreated, installationA, "2026-06-30T15:10:00Z", questA),
        event(3, "a-completed-0", .questCompleted, installationA, "2026-06-30T15:20:00Z", questA),
        event(4, "a-activation-d1", .appActivated, installationA, "2026-07-01T16:00:00Z"),
        event(5, "a-activation-d7", .appActivated, installationA, "2026-07-07T16:00:00Z"),
        event(6, "a-completed-1", .questCompleted, installationA, "2026-07-08T01:00:00Z", questA),
        event(7, "a-completed-2", .questCompleted, installationA, "2026-07-09T01:00:00Z", questA),
        event(8, "b-activation-0", .appActivated, installationB, "2026-07-01T15:00:00Z"),
        event(9, "b-created", .questCreated, installationB, "2026-07-01T15:10:00Z", questB),
        event(10, "b-completed", .questCompleted, installationB, "2026-07-01T15:20:00Z", questB),
        event(11, "b-activation-d1", .appActivated, installationB, "2026-07-02T16:00:00Z"),
        event(12, "c-activation-0", .appActivated, installationC, "2026-07-02T15:00:00Z"),
        event(13, "c-activation-week", .appActivated, installationC, "2026-07-11T01:00:00Z"),
        event(14, "d-activation-0", .appActivated, installationD, "2026-07-11T15:00:00Z"),
        event(15, "d-created", .questCreated, installationD, "2026-07-11T15:10:00Z", questD),
    ]

    static let expectation = RetentionScenarioExpectation(
        requiredKeys: Set(events.map(\.deduplicationKey)),
        forbiddenKeys: []
    )

    static func event(
        _ id: Int,
        _ key: String,
        _ name: RetentionEventName,
        _ installationID: UUID,
        _ occurredAt: String,
        _ questID: UUID? = nil,
        source: RetentionEventSource = .app
    ) -> RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: uuid(1_000 + id),
            schemaVersion: 1,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: date(occurredAt),
            sourceRawValue: source.rawValue,
            questID: questID,
            deduplicationKey: key
        )
    }

    static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}
