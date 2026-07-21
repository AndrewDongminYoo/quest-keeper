import Foundation
import Testing
@testable import QuestKeeper

struct RetentionReportTests {
    @Test("fixture produces the approved funnel and retention denominators")
    func fixtureProducesApprovedMetrics() {
        let report = makeReport()

        #expect(report.firstValue == RetentionRate(achieved: 3, eligible: 4))
        #expect(report.firstCompletion == RetentionRate(achieved: 2, eligible: 3))
        #expect(report.d1 == RetentionRate(achieved: 2, eligible: 4))
        #expect(report.d7 == RetentionRate(achieved: 1, eligible: 3))
        #expect(report.weeklyActiveInstallations == 3)
        #expect(report.weeklyRepeatedCompletion == RetentionRate(achieved: 1, eligible: 3))
        #expect(report.dataQuality.status == .complete)
    }

    @Test("scenario validation identifies one exact missing key")
    func scenarioMissingKey() {
        let removed = RetentionBaselineFixture.events[1]
        let report = makeReport(events: RetentionBaselineFixture.events.filter { $0.id != removed.id })

        #expect(report.scenarioValidation.missingKeys == [removed.deduplicationKey])
        #expect(report.dataQuality.missingCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("canonicalization reports duplicate rows without double counting")
    func duplicateRows() {
        let original = RetentionBaselineFixture.events[5]
        let duplicate = RetentionEventSnapshot(
            id: RetentionBaselineFixture.uuid(9_999),
            schemaVersion: original.schemaVersion,
            nameRawValue: original.nameRawValue,
            installationID: original.installationID,
            occurredAt: original.occurredAt.addingTimeInterval(1),
            sourceRawValue: original.sourceRawValue,
            questID: original.questID,
            deduplicationKey: original.deduplicationKey
        )
        let report = makeReport(events: RetentionBaselineFixture.events + [duplicate])

        #expect(report.dataQuality.duplicateCountsByEvent[RetentionEventName.questCompleted.rawValue] == 1)
        #expect(report.weeklyRepeatedCompletion == RetentionRate(achieved: 1, eligible: 3))
        #expect(report.dataQuality.status == .partial)
    }

    @Test("forbidden scenario keys are reported")
    func forbiddenScenarioKey() {
        let forbidden = "forbidden-event"
        let expectation = RetentionScenarioExpectation(
            requiredKeys: RetentionBaselineFixture.expectation.requiredKeys,
            forbiddenKeys: [forbidden]
        )
        let event = RetentionBaselineFixture.event(
            100,
            forbidden,
            .questRetried,
            RetentionBaselineFixture.installationA,
            "2026-07-08T02:00:00Z",
            RetentionBaselineFixture.questA
        )
        let report = makeReport(events: RetentionBaselineFixture.events + [event], expectation: expectation)

        #expect(report.scenarioValidation.forbiddenKeys == [forbidden])
        #expect(report.dataQuality.forbiddenCount == 1)
    }

    @Test("invalid timing and unsupported rows remain partial instead of being inferred")
    func invalidRows() {
        let unknownName = rawEvent(
            id: 201,
            key: "unknown-name",
            name: "unknown",
            source: "app",
            at: "2026-07-08T03:00:00Z"
        )
        let unknownSource = rawEvent(
            id: 202,
            key: "unknown-source",
            name: "app_activated",
            source: "unknown",
            at: "2026-07-08T03:00:00Z"
        )
        let beforeMeasurement = rawEvent(
            id: 203,
            key: "before-measurement",
            name: "app_activated",
            source: "app",
            at: "2026-06-29T15:00:00Z"
        )
        let future = rawEvent(
            id: 204,
            key: "future",
            name: "app_activated",
            source: "app",
            at: "2026-07-14T15:00:00Z"
        )
        let report = makeReport(events: RetentionBaselineFixture.events + [
            unknownName, unknownSource, beforeMeasurement, future,
        ])

        #expect(report.dataQuality.unsupportedCount == 2)
        #expect(report.dataQuality.preMeasurementCount == 1)
        #expect(report.dataQuality.futureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("completion before creation is orphaned and receives no funnel credit")
    func orphanCompletion() {
        let orphanInstallation = RetentionBaselineFixture.uuid(20)
        let startedAt = RetentionBaselineFixture.date("2026-07-10T15:00:00Z")
        let installation = RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: orphanInstallation,
            measurementStartedAt: startedAt
        )
        let activation = RetentionBaselineFixture.event(
            301,
            "orphan-activation",
            .appActivated,
            orphanInstallation,
            "2026-07-10T15:00:00Z"
        )
        let completion = RetentionBaselineFixture.event(
            302,
            "orphan-completion",
            .questCompleted,
            orphanInstallation,
            "2026-07-10T15:05:00Z",
            RetentionBaselineFixture.uuid(201)
        )
        let report = makeReport(
            installations: RetentionBaselineFixture.installations + [installation],
            events: RetentionBaselineFixture.events + [activation, completion],
            expectation: nil
        )

        #expect(report.firstValue == RetentionRate(achieved: 3, eligible: 5))
        #expect(report.firstCompletion == RetentionRate(achieved: 2, eligible: 3))
        #expect(report.dataQuality.orphanCompletionCount == 1)
    }

    @Test("D1 requires the exact local day and D7 excludes a young installation")
    func calendarWindows() {
        let d2Activation = RetentionBaselineFixture.event(
            401,
            "c-activation-d2",
            .appActivated,
            RetentionBaselineFixture.installationC,
            "2026-07-04T16:00:00Z"
        )
        let report = makeReport(events: RetentionBaselineFixture.events + [d2Activation], expectation: nil)

        #expect(report.d1 == RetentionRate(achieved: 2, eligible: 4))
        #expect(report.d7 == RetentionRate(achieved: 1, eligible: 3))
    }

    @Test("Markdown rendering is deterministic")
    func markdownIsDeterministic() {
        let report = makeReport()
        #expect(report.renderMarkdown() == report.renderMarkdown())
    }

    private func makeReport(
        installations: [RetentionInstallationSnapshot] = RetentionBaselineFixture.installations,
        events: [RetentionEventSnapshot] = RetentionBaselineFixture.events,
        expectation: RetentionScenarioExpectation? = RetentionBaselineFixture.expectation
    ) -> RetentionReport {
        RetentionReport.make(
            installations: installations,
            events: events,
            asOf: RetentionBaselineFixture.asOf,
            calendar: RetentionBaselineFixture.calendar,
            reportingWeek: RetentionBaselineFixture.reportingWeek,
            expectation: expectation
        )
    }

    private func rawEvent(
        id: Int,
        key: String,
        name: String,
        source: String,
        at: String
    ) -> RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: RetentionBaselineFixture.uuid(id),
            schemaVersion: 1,
            nameRawValue: name,
            installationID: RetentionBaselineFixture.installationA,
            occurredAt: RetentionBaselineFixture.date(at),
            sourceRawValue: source,
            questID: nil,
            deduplicationKey: key
        )
    }
}
