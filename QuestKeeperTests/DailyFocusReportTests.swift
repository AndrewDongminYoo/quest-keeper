import Foundation
import Testing
@testable import QuestKeeper

struct DailyFocusReportTests {
    private let installationID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let missingInstallationID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let firstQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let thirdQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    private let fourthQuestID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!

    @Test("report calculates explicit selection completion edit and next-day rates")
    func calculatesDailyFocusMetrics() throws {
        let selections = [
            try selection(1, day: 1, hour: 9, questIDs: [firstQuestID, secondQuestID], kind: .confirmation),
            try selection(2, day: 1, hour: 10, questIDs: [secondQuestID, thirdQuestID], kind: .revision),
            try selection(3, day: 3, hour: 9, questIDs: [fourthQuestID], kind: .confirmation),
        ]
        let events = [
            activation(11, day: 1),
            completion(12, day: 1, hour: 11, questID: firstQuestID),
            activation(13, day: 2),
            activation(14, day: 3),
            completion(15, day: 3, hour: 10, questID: fourthQuestID),
            activation(16, day: 4),
        ]

        let report = DailyFocusReport.make(
            selections: selections,
            installations: [installation()],
            events: events,
            asOf: date(day: 5),
            calendar: calendar,
            reportingInterval: DateInterval(start: date(day: 1), end: date(day: 5))
        )

        #expect(report.dailySelection == RetentionRate(achieved: 2, eligible: 4))
        #expect(report.focusQuestCompletion == RetentionRate(achieved: 2, eligible: 4))
        #expect(report.selectedDayCompletion == RetentionRate(achieved: 2, eligible: 2))
        #expect(report.nextDayRevisit == RetentionRate(achieved: 2, eligible: 2))
        #expect(report.editRate == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.dataQuality.status == .complete)
    }

    @Test("current day completion and unfinished next day are right censored")
    func rightCensorsIncompleteWindows() throws {
        let selection = try selection(
            1,
            day: 3,
            hour: 9,
            questIDs: [firstQuestID],
            kind: .confirmation
        )

        let report = DailyFocusReport.make(
            selections: [selection],
            installations: [installation()],
            events: [activation(2, day: 3)],
            asOf: date(day: 3, hour: 12),
            calendar: calendar,
            reportingInterval: DateInterval(start: date(day: 1), end: date(day: 5))
        )

        #expect(report.dailySelection == RetentionRate(achieved: 1, eligible: 1))
        #expect(report.focusQuestCompletion == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.selectedDayCompletion == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.nextDayRevisit == RetentionRate(achieved: 0, eligible: 0))
        #expect(report.editRate == RetentionRate(achieved: 0, eligible: 1))
    }

    @Test("invalid snapshots are excluded and counted")
    func reportsDataQualityFailures() throws {
        let unsupported = DailyFocusSelectionSnapshot(
            id: UUID(),
            schemaVersion: 99,
            installationID: installationID,
            localDayKey: "2026-06-01",
            timeZoneIdentifier: "UTC",
            selectedQuestIDsData: try JSONEncoder().encode([firstQuestID.uuidString]),
            recordedAt: date(day: 1, hour: 9),
            kindRawValue: DailyFocusSelectionKind.confirmation.rawValue
        )
        let malformed = DailyFocusSelectionSnapshot(
            id: UUID(),
            schemaVersion: 1,
            installationID: installationID,
            localDayKey: "2026-06-01",
            timeZoneIdentifier: "UTC",
            selectedQuestIDsData: Data("not-json".utf8),
            recordedAt: date(day: 1, hour: 9),
            kindRawValue: DailyFocusSelectionKind.confirmation.rawValue
        )
        let missingInstallation = try selection(
            3,
            day: 1,
            hour: 9,
            questIDs: [firstQuestID],
            kind: .confirmation,
            installationID: missingInstallationID
        )
        let revisionBeforeConfirmation = try selection(
            4,
            day: 1,
            hour: 9,
            questIDs: [firstQuestID],
            kind: .revision
        )

        let report = DailyFocusReport.make(
            selections: [unsupported, malformed, missingInstallation, revisionBeforeConfirmation],
            installations: [installation()],
            events: [],
            asOf: date(day: 5),
            calendar: calendar,
            reportingInterval: DateInterval(start: date(day: 1), end: date(day: 5))
        )

        #expect(report.dataQuality.status == .partial)
        #expect(report.dataQuality.unsupportedCount == 1)
        #expect(report.dataQuality.malformedCount == 1)
        #expect(report.dataQuality.missingInstallationCount == 1)
        #expect(report.dataQuality.outOfOrderCount == 1)
        #expect(report.dailySelection == RetentionRate(achieved: 0, eligible: 0))
    }

    @Test("empty inputs render absent rates")
    func emptyReport() {
        let report = DailyFocusReport.make(
            selections: [],
            installations: [],
            events: [],
            asOf: date(day: 5),
            calendar: calendar,
            reportingInterval: DateInterval(start: date(day: 1), end: date(day: 5))
        )

        #expect(report.dailySelection.value == nil)
        #expect(report.focusQuestCompletion.value == nil)
        #expect(report.selectedDayCompletion.value == nil)
        #expect(report.nextDayRevisit.value == nil)
        #expect(report.editRate.value == nil)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: day,
            hour: hour
        ))!
    }

    private func installation() -> RetentionInstallationSnapshot {
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationID,
            measurementStartedAt: date(day: 1).addingTimeInterval(-60)
        )
    }

    private func selection(
        _ idSuffix: Int,
        day: Int,
        hour: Int,
        questIDs: [UUID],
        kind: DailyFocusSelectionKind,
        installationID: UUID? = nil
    ) throws -> DailyFocusSelectionSnapshot {
        let recordedAt = date(day: day, hour: hour)
        return DailyFocusSelectionSnapshot(
            id: uuid(idSuffix),
            schemaVersion: 1,
            installationID: installationID ?? self.installationID,
            localDayKey: DailyFocusDay.key(for: recordedAt, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier,
            selectedQuestIDsData: try JSONEncoder().encode(questIDs.map(\.uuidString)),
            recordedAt: recordedAt,
            kindRawValue: kind.rawValue
        )
    }

    private func activation(_ idSuffix: Int, day: Int) -> RetentionEventSnapshot {
        event(idSuffix, name: .appActivated, day: day, hour: 8, questID: nil)
    }

    private func completion(
        _ idSuffix: Int,
        day: Int,
        hour: Int,
        questID: UUID
    ) -> RetentionEventSnapshot {
        event(idSuffix, name: .questCompleted, day: day, hour: hour, questID: questID)
    }

    private func event(
        _ idSuffix: Int,
        name: RetentionEventName,
        day: Int,
        hour: Int,
        questID: UUID?
    ) -> RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: uuid(idSuffix),
            schemaVersion: 1,
            nameRawValue: name.rawValue,
            installationID: installationID,
            occurredAt: date(day: day, hour: hour),
            sourceRawValue: RetentionEventSource.app.rawValue,
            questID: questID,
            deduplicationKey: "\(name.rawValue):\(installationID):\(idSuffix)"
        )
    }

    private func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}
