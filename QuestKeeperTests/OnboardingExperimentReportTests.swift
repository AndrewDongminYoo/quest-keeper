import Foundation
import Testing
@testable import QuestKeeper

struct OnboardingExperimentReportTests {
    @Test("fixture produces approved variant funnels and rates")
    func fixtureMetrics() {
        let report = makeReport()

        #expect(report.control.funnel == OnboardingExperimentFixture.expectedControlFunnel)
        #expect(report.guided.funnel == OnboardingExperimentFixture.expectedGuidedFunnel)
        #expect(report.control.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.guided.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.control.firstSuccessWithinTwoMinutes == RetentionRate(achieved: 0, eligible: 2))
        #expect(report.guided.firstSuccessWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.control.firstQuestCompletion == RetentionRate(achieved: 1, eligible: 1))
        #expect(report.guided.firstQuestCompletion == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.control.medianTimeToFirstValueSeconds == 60)
        #expect(report.guided.medianTimeToFirstValueSeconds == 120)
        #expect(report.control.d1 == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.guided.d1 == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.control.d7 == RetentionRate(achieved: 1, eligible: 1))
        #expect(report.guided.d7 == RetentionRate(achieved: 0, eligible: 1))
        #expect(report.guidedDeferral == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.dataQuality.status == .complete)
    }

    @Test("two minute boundary is inclusive and immature exposures are excluded")
    func twoMinuteBoundary() {
        let installationID = OnboardingExperimentFixture.uuid(20)
        let assignment = OnboardingExperimentFixture.assignment(installationID, .control, "2026-07-01T15:00:00Z")
        let installation = installation(for: assignment)
        let exposure = OnboardingExperimentFixture.event(201, .experimentExposed, installationID, "2026-07-01T15:00:00Z")
        let start = OnboardingExperimentFixture.event(202, .questCreationStarted, installationID, "2026-07-01T15:00:01Z")
        let creation = OnboardingExperimentFixture.event(203, .questCreated, installationID, "2026-07-01T15:02:00Z", OnboardingExperimentFixture.uuid(220))

        let mature = makeReport(
            assignments: [assignment],
            installations: [installation],
            events: [exposure, start, creation],
            asOf: OnboardingExperimentFixture.date("2026-07-01T15:02:00Z")
        )
        let immature = makeReport(
            assignments: [assignment],
            installations: [installation],
            events: [exposure, start],
            asOf: OnboardingExperimentFixture.date("2026-07-01T15:01:59Z")
        )

        #expect(mature.control.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 1, eligible: 1))
        #expect(immature.control.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 0, eligible: 0))
    }

    @Test("an immature two minute window contributes to neither numerator nor denominator")
    func immatureTwoMinuteWindow() {
        let installationID = OnboardingExperimentFixture.uuid(22)
        let assignment = OnboardingExperimentFixture.assignment(installationID, .control, "2026-07-01T15:00:00Z")
        let exposure = OnboardingExperimentFixture.event(221, .experimentExposed, installationID, "2026-07-01T15:00:00Z")
        let creation = OnboardingExperimentFixture.event(
            222,
            .questCreated,
            installationID,
            "2026-07-01T15:01:00Z",
            OnboardingExperimentFixture.uuid(223)
        )

        let report = makeReport(
            assignments: [assignment],
            installations: [installation(for: assignment)],
            events: [exposure, creation],
            asOf: OnboardingExperimentFixture.date("2026-07-01T15:01:30Z")
        )

        #expect(report.control.funnel.firstValue == 1)
        #expect(report.control.onboardingCompletionWithinTwoMinutes == RetentionRate(achieved: 0, eligible: 0))
    }

    @Test("D1 requires the complete local target day and does not backfill late activation")
    func localDayRetention() {
        let installationID = OnboardingExperimentFixture.uuid(21)
        let assignment = OnboardingExperimentFixture.assignment(installationID, .control, "2026-07-01T16:00:00Z")
        let installation = installation(for: assignment)
        let exposure = OnboardingExperimentFixture.event(211, .experimentExposed, installationID, "2026-07-01T16:00:00Z")
        let lateActivation = OnboardingExperimentFixture.event(212, .appActivated, installationID, "2026-07-03T16:00:00Z")

        let beforeTargetDayEnds = makeReport(
            assignments: [assignment],
            installations: [installation],
            events: [exposure],
            asOf: OnboardingExperimentFixture.date("2026-07-02T14:59:59Z")
        )
        let afterTargetDay = makeReport(
            assignments: [assignment],
            installations: [installation],
            events: [exposure, lateActivation],
            asOf: OnboardingExperimentFixture.date("2026-07-03T15:00:00Z")
        )

        #expect(beforeTargetDayEnds.control.d1 == RetentionRate(achieved: 0, eligible: 0))
        #expect(afterTargetDay.control.d1 == RetentionRate(achieved: 0, eligible: 1))
    }

    @Test("completion for another quest inside the window excludes the contaminated installation")
    func differentQuestCompletion() {
        var events = OnboardingExperimentFixture.events.filter { $0.id != OnboardingExperimentFixture.uuid(1_012) }
        events.append(OnboardingExperimentFixture.event(
            301,
            .questCompleted,
            OnboardingExperimentFixture.guidedA,
            "2026-07-01T15:01:40Z",
            OnboardingExperimentFixture.uuid(999)
        ))

        let report = makeReport(events: events)

        #expect(report.guided.funnel.exposed == 1)
        #expect(report.guided.funnel.firstValue == 1)
        #expect(report.dataQuality.orderingFailureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("a later completion for another quest preserves the onboarding journey")
    func laterDifferentQuestCompletion() {
        let laterCompletion = OnboardingExperimentFixture.event(
            306,
            .questCompleted,
            OnboardingExperimentFixture.guidedA,
            "2026-07-01T15:06:00Z",
            OnboardingExperimentFixture.uuid(999)
        )

        let report = makeReport(events: OnboardingExperimentFixture.events + [laterCompletion])

        #expect(report.guided.funnel == OnboardingExperimentFixture.expectedGuidedFunnel)
        #expect(report.guided.firstQuestCompletion == RetentionRate(achieved: 1, eligible: 2))
        #expect(report.dataQuality.orderingFailureCount == 0)
        #expect(report.dataQuality.status == .complete)
    }

    @Test("a different-quest completion at the exact boundary still contaminates")
    func differentQuestCompletionAtBoundary() {
        var events = OnboardingExperimentFixture.events.filter { $0.id != OnboardingExperimentFixture.uuid(1_012) }
        // Boundary is exposure (15:00:00) + 120s = 15:02:00. A mismatched completion at the
        // exact boundary is still inside the observation window, so it must contaminate.
        events.append(OnboardingExperimentFixture.event(
            302,
            .questCompleted,
            OnboardingExperimentFixture.guidedA,
            "2026-07-01T15:02:00Z",
            OnboardingExperimentFixture.uuid(999)
        ))

        let report = makeReport(events: events)

        #expect(report.guided.funnel.exposed == 1)
        #expect(report.guided.funnel.firstValue == 1)
        #expect(report.dataQuality.orderingFailureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("duplicate event keys exclude the contaminated installation")
    func duplicateEvents() {
        let original = OnboardingExperimentFixture.events[10]
        let duplicate = RetentionEventSnapshot(
            id: OnboardingExperimentFixture.uuid(9_001),
            schemaVersion: original.schemaVersion,
            nameRawValue: original.nameRawValue,
            installationID: original.installationID,
            occurredAt: original.occurredAt.addingTimeInterval(1),
            sourceRawValue: original.sourceRawValue,
            questID: original.questID,
            deduplicationKey: original.deduplicationKey
        )

        let report = makeReport(events: OnboardingExperimentFixture.events + [duplicate])

        #expect(report.guided.funnel.exposed == 1)
        #expect(report.guided.funnel.firstValue == 1)
        #expect(report.dataQuality.duplicateCountsByEvent[RetentionEventName.questCreated.rawValue] == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("first value remains independent when creation start is missing")
    func creationWithoutStart() {
        let events = OnboardingExperimentFixture.events.filter {
            $0.id != OnboardingExperimentFixture.uuid(1_010)
        }

        let report = makeReport(events: events)

        #expect(report.guided.funnel.exposed == 2)
        #expect(report.guided.funnel.creationStarted == 1)
        #expect(report.guided.funnel.firstValue == 2)
        #expect(report.guided.funnel.firstCompletion == 1)
    }

    @Test("a supported assignment beside an unsupported row is excluded")
    func mixedSupportedAndUnsupportedAssignments() {
        let unsupported = ExperimentAssignmentSnapshot(
            schemaVersion: 2,
            experimentKey: OnboardingExperiment.key,
            installationID: OnboardingExperimentFixture.controlA,
            variantRawValue: OnboardingExperimentVariant.control.rawValue,
            assignedAt: OnboardingExperimentFixture.assignments[0].assignedAt
        )

        let report = makeReport(assignments: OnboardingExperimentFixture.assignments + [unsupported])

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.unsupportedCount == 1)
        #expect(report.dataQuality.conflictingAssignmentCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("a supported installation beside an unsupported row is excluded")
    func mixedSupportedAndUnsupportedInstallations() {
        let unsupported = RetentionInstallationSnapshot(
            schemaVersion: 2,
            installationID: OnboardingExperimentFixture.controlA,
            measurementStartedAt: OnboardingExperimentFixture.assignments[0].assignedAt
        )

        let report = makeReport(
            installations: OnboardingExperimentFixture.installations + [unsupported]
        )

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.unsupportedCount == 1)
        #expect(report.dataQuality.crossInstallationMismatchCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("another experiment exposure cannot enter the AND-34 cohort")
    func differentExperimentExposure() {
        let events = OnboardingExperimentFixture.events.map { event in
            guard event.installationID == OnboardingExperimentFixture.controlA,
                  event.name == .experimentExposed else {
                return event
            }
            return RetentionEventSnapshot(
                id: event.id,
                schemaVersion: event.schemaVersion,
                nameRawValue: event.nameRawValue,
                installationID: event.installationID,
                occurredAt: event.occurredAt,
                sourceRawValue: event.sourceRawValue,
                questID: event.questID,
                deduplicationKey: "experiment_exposed:\(event.installationID.uuidString):another-experiment"
            )
        }

        let report = makeReport(events: events)

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.missingExposureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("completion before first creation excludes the contaminated installation")
    func completionBeforeCreation() {
        var events = OnboardingExperimentFixture.events.filter {
            $0.id != OnboardingExperimentFixture.uuid(1_004)
        }
        events.append(OnboardingExperimentFixture.event(
            304,
            .questCompleted,
            OnboardingExperimentFixture.controlA,
            "2026-07-01T15:00:30Z",
            OnboardingExperimentFixture.controlQuest
        ))

        let report = makeReport(events: events)

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.orderingFailureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("creation start after first value excludes the contaminated installation")
    func creationStartAfterCreation() {
        var events = OnboardingExperimentFixture.events.filter {
            $0.id != OnboardingExperimentFixture.uuid(1_002)
        }
        events.append(OnboardingExperimentFixture.event(
            302,
            .questCreationStarted,
            OnboardingExperimentFixture.controlA,
            "2026-07-01T15:02:00Z"
        ))

        let report = makeReport(events: events)

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.orderingFailureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("an unsupported event excludes its assigned installation")
    func unsupportedEventContamination() {
        var events = OnboardingExperimentFixture.events
        events.append(OnboardingExperimentFixture.event(
            305,
            .appActivated,
            OnboardingExperimentFixture.guidedA,
            "2026-07-03T16:00:00Z",
            schemaVersion: 2
        ))

        let report = makeReport(events: events)

        #expect(report.guided.funnel.exposed == 1)
        #expect(report.dataQuality.unsupportedCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("an AND-34 event without an assignment is reported")
    func missingAssignmentEvent() {
        let installationID = OnboardingExperimentFixture.uuid(306)
        let installation = RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: installationID,
            measurementStartedAt: OnboardingExperimentFixture.cohort.start
        )
        let exposure = OnboardingExperimentFixture.event(
            306,
            .experimentExposed,
            installationID,
            "2026-07-01T15:00:00Z"
        )

        let report = makeReport(
            installations: OnboardingExperimentFixture.installations + [installation],
            events: OnboardingExperimentFixture.events + [exposure]
        )

        #expect(report.dataQuality.crossInstallationMismatchCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("missing exposure excludes the assignment from funnel denominators")
    func missingExposure() {
        let events = OnboardingExperimentFixture.events.filter {
            !($0.installationID == OnboardingExperimentFixture.controlB && $0.name == .experimentExposed)
        }
        let report = makeReport(events: events)

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.missingExposureCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("conflicting assignments are excluded")
    func conflictingAssignments() {
        let conflict = ExperimentAssignmentSnapshot(
            schemaVersion: 1,
            experimentKey: OnboardingExperiment.key,
            installationID: OnboardingExperimentFixture.controlA,
            variantRawValue: OnboardingExperimentVariant.guided.rawValue,
            assignedAt: OnboardingExperimentFixture.assignments[0].assignedAt
        )
        let report = makeReport(assignments: OnboardingExperimentFixture.assignments + [conflict])

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.conflictingAssignmentCount == 1)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("identical duplicate assignments are excluded and reported")
    func duplicateAssignments() {
        let duplicate = OnboardingExperimentFixture.assignments[0]
        let report = makeReport(assignments: OnboardingExperimentFixture.assignments + [duplicate])

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.duplicateAssignmentCount == 1)
    }

    @Test("unsupported assignment variants and schema versions are excluded")
    func unsupportedAssignments() {
        let unsupportedVariant = ExperimentAssignmentSnapshot(
            schemaVersion: 1,
            experimentKey: OnboardingExperiment.key,
            installationID: OnboardingExperimentFixture.uuid(31),
            variantRawValue: "unknown",
            assignedAt: OnboardingExperimentFixture.cohort.start
        )
        let unsupportedSchema = ExperimentAssignmentSnapshot(
            schemaVersion: 2,
            experimentKey: OnboardingExperiment.key,
            installationID: OnboardingExperimentFixture.uuid(32),
            variantRawValue: OnboardingExperimentVariant.control.rawValue,
            assignedAt: OnboardingExperimentFixture.cohort.start
        )
        let report = makeReport(assignments: OnboardingExperimentFixture.assignments + [unsupportedVariant, unsupportedSchema])

        #expect(report.dataQuality.unsupportedCount == 2)
        #expect(report.dataQuality.status == .partial)
    }

    @Test("exposure before assignment is an ordering failure")
    func exposureBeforeAssignment() {
        var events = OnboardingExperimentFixture.events.filter { $0.id != OnboardingExperimentFixture.uuid(1_001) }
        events.append(OnboardingExperimentFixture.event(
            401,
            .experimentExposed,
            OnboardingExperimentFixture.controlA,
            "2026-07-01T14:59:59Z"
        ))
        let report = makeReport(events: events)

        #expect(report.control.funnel.exposed == 1)
        #expect(report.dataQuality.orderingFailureCount == 1)
    }

    @Test("event and installation mismatches are excluded")
    func crossInstallationMismatch() {
        let unmatched = OnboardingExperimentFixture.event(
            411,
            .experimentExposed,
            OnboardingExperimentFixture.uuid(999),
            "2026-07-01T15:00:00Z"
        )
        let report = makeReport(events: OnboardingExperimentFixture.events + [unmatched])

        #expect(report.dataQuality.crossInstallationMismatchCount == 1)
    }

    @Test("out of cohort assignments are ignored")
    func outOfCohortAssignment() {
        let installationID = OnboardingExperimentFixture.uuid(41)
        let assignment = OnboardingExperimentFixture.assignment(installationID, .guided, "2026-07-08T15:00:00Z")
        let exposure = OnboardingExperimentFixture.event(421, .experimentExposed, installationID, "2026-07-08T15:00:00Z")
        let report = makeReport(
            assignments: OnboardingExperimentFixture.assignments + [assignment],
            installations: OnboardingExperimentFixture.installations + [installation(for: assignment)],
            events: OnboardingExperimentFixture.events + [exposure]
        )

        #expect(report.guided.funnel.exposed == 2)
        #expect(report.dataQuality.status == .complete)
    }

    @Test("empty input produces unavailable rates")
    func emptyRates() {
        let report = makeReport(assignments: [], installations: [], events: [])

        #expect(report.control.onboardingCompletionWithinTwoMinutes.value == nil)
        #expect(report.guided.firstSuccessWithinTwoMinutes.value == nil)
        #expect(report.guidedDeferral.value == nil)
    }

    @Test("Markdown is deterministic and contains no private quest content")
    func deterministicSafeMarkdown() {
        let report = makeReport()
        let markdown = report.renderMarkdown()

        #expect(markdown == report.renderMarkdown())
        #expect(markdown.contains("QuestKeeper Synthetic Onboarding Experiment Baseline"))
        #expect(markdown.localizedCaseInsensitiveContains("synthetic"))
        #expect(!markdown.contains("물 한 잔 마시기"))
        #expect(!markdown.contains(OnboardingExperimentFixture.controlA.uuidString))
    }

    @Test("checked-in synthetic baseline matches the deterministic renderer")
    func checkedInBaselineMatchesRenderer() throws {
        let noteURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/notes/013-onboarding-experiment-baseline.md")

        #expect(try String(contentsOf: noteURL, encoding: .utf8) == makeReport().renderMarkdown())
    }

    private func makeReport(
        assignments: [ExperimentAssignmentSnapshot] = OnboardingExperimentFixture.assignments,
        installations: [RetentionInstallationSnapshot] = OnboardingExperimentFixture.installations,
        events: [RetentionEventSnapshot] = OnboardingExperimentFixture.events,
        asOf: Date = OnboardingExperimentFixture.asOf
    ) -> OnboardingExperimentReport {
        OnboardingExperimentReport.make(
            assignments: assignments,
            installations: installations,
            events: events,
            asOf: asOf,
            calendar: OnboardingExperimentFixture.calendar,
            cohort: OnboardingExperimentFixture.cohort
        )
    }

    private func installation(for assignment: ExperimentAssignmentSnapshot) -> RetentionInstallationSnapshot {
        RetentionInstallationSnapshot(
            schemaVersion: 1,
            installationID: assignment.installationID,
            measurementStartedAt: assignment.assignedAt
        )
    }
}
