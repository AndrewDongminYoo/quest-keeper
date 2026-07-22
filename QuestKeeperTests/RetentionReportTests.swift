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

    @Test("experiment events do not alter core metrics")
    func experimentEventsPreserveCoreMetrics() {
        let experimentEvents = [
            RetentionBaselineFixture.event(
                601,
                "experiment-exposed",
                .experimentExposed,
                RetentionBaselineFixture.installationA,
                "2026-06-30T15:00:01Z"
            ),
            RetentionBaselineFixture.event(
                602,
                "quest-creation-started",
                .questCreationStarted,
                RetentionBaselineFixture.installationA,
                "2026-06-30T15:00:02Z"
            ),
            RetentionBaselineFixture.event(
                603,
                "onboarding-deferred",
                .onboardingDeferred,
                RetentionBaselineFixture.installationA,
                "2026-06-30T15:00:03Z"
            ),
        ]

        let baseline = makeReport()
        let report = makeReport(events: RetentionBaselineFixture.events + experimentEvents)

        #expect(report.firstValue == baseline.firstValue)
        #expect(report.firstCompletion == baseline.firstCompletion)
        #expect(report.d1 == baseline.d1)
        #expect(report.d7 == baseline.d7)
        #expect(report.weeklyActiveInstallations == baseline.weeklyActiveInstallations)
        #expect(report.weeklyRepeatedCompletion == baseline.weeklyRepeatedCompletion)
        #expect(report.dataQuality.unsupportedCount == 0)
    }

    @Test("experiment events reject widget sources and quest identifiers")
    func invalidExperimentEventFieldsAreUnsupported() {
        let invalidEvents = [
            rawEvent(
                id: 611,
                key: "widget-exposure",
                name: "experiment_exposed",
                source: "widget",
                at: "2026-07-08T03:00:00Z"
            ),
            rawEvent(
                id: 612,
                key: "creation-start-with-quest",
                name: "quest_creation_started",
                source: "app",
                at: "2026-07-08T03:00:00Z",
                questID: RetentionBaselineFixture.questA
            ),
            rawEvent(
                id: 613,
                key: "deferred-with-quest",
                name: "onboarding_deferred",
                source: "app",
                at: "2026-07-08T03:00:00Z",
                questID: RetentionBaselineFixture.questA
            ),
        ]

        let report = makeReport(events: RetentionBaselineFixture.events + invalidEvents)

        #expect(report.dataQuality.unsupportedCount == 3)
        #expect(report.dataQuality.status == .partial)
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
        let widgetCreation = rawEvent(
            id: 205,
            key: "widget-creation",
            name: "quest_created",
            source: "widget",
            at: "2026-07-08T03:00:00Z",
            questID: RetentionBaselineFixture.questA
        )
        let activationWithQuest = rawEvent(
            id: 206,
            key: "activation-with-quest",
            name: "app_activated",
            source: "app",
            at: "2026-07-08T03:00:00Z",
            questID: RetentionBaselineFixture.questA
        )
        let completionWithoutQuest = rawEvent(
            id: 207,
            key: "completion-without-quest",
            name: "quest_completed",
            source: "app",
            at: "2026-07-08T03:00:00Z"
        )
        let report = makeReport(events: RetentionBaselineFixture.events + [
            unknownName, unknownSource, beforeMeasurement, future,
            widgetCreation, activationWithQuest, completionWithoutQuest,
        ])

        #expect(report.dataQuality.unsupportedCount == 5)
        #expect(report.dataQuality.preMeasurementCount == 1)
        #expect(report.dataQuality.futureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("creation before first activation is reported as an ordering failure")
    func creationBeforeActivation() {
        let installationID = RetentionBaselineFixture.uuid(30)
        let installation = RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationID,
            measurementStartedAt: RetentionBaselineFixture.date("2026-07-10T15:00:00Z")
        )
        let creation = RetentionBaselineFixture.event(
            501,
            "creation-before-activation",
            .questCreated,
            installationID,
            "2026-07-10T15:01:00Z",
            RetentionBaselineFixture.uuid(301)
        )
        let activation = RetentionBaselineFixture.event(
            502,
            "activation-after-creation",
            .appActivated,
            installationID,
            "2026-07-10T15:02:00Z"
        )
        let report = makeReport(
            installations: RetentionBaselineFixture.installations + [installation],
            events: RetentionBaselineFixture.events + [creation, activation],
            expectation: nil
        )

        #expect(report.dataQuality.preActivationCreationCount == 1)
        #expect(report.dataQuality.status == .partial)
        #expect(report.firstValue == RetentionRate(achieved: 3, eligible: 5))
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

    @Test("checked-in synthetic baseline matches the deterministic renderer")
    func checkedInBaselineMatchesRenderer() throws {
        let noteURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/notes/012-retention-baseline.md")

        #expect(try String(contentsOf: noteURL, encoding: .utf8) == makeReport().renderMarkdown())
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
        at: String,
        questID: UUID? = nil
    ) -> RetentionEventSnapshot {
        RetentionEventSnapshot(
            id: RetentionBaselineFixture.uuid(id),
            schemaVersion: 1,
            nameRawValue: name,
            installationID: RetentionBaselineFixture.installationA,
            occurredAt: RetentionBaselineFixture.date(at),
            sourceRawValue: source,
            questID: questID,
            deduplicationKey: key
        )
    }
}
