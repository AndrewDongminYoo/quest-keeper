import Foundation
import OSLog
import SwiftData

@MainActor
final class RetentionBaselineWriter {
    private let store: RetentionBaselineStore
    private let onboardingStore: OnboardingExperimentStore
    private let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "RetentionMeasurement"
    )

    init(
        store: RetentionBaselineStore = RetentionBaselineStore(),
        onboardingStore: OnboardingExperimentStore = OnboardingExperimentStore()
    ) {
        self.store = store
        self.onboardingStore = onboardingStore
    }

    func recordActivationAndWrite(
        sessionID: UUID,
        at now: Date,
        using container: ModelContainer,
        calendar: Calendar = .current
    ) {
        _ = RetentionEventRecorder.recordActivation(
            sessionID: sessionID,
            at: now,
            in: container.mainContext
        )

        do {
            if container.mainContext.hasChanges {
                try container.mainContext.save()
            }
            let installations = try container.mainContext.fetch(
                FetchDescriptor<RetentionInstallation>(sortBy: [SortDescriptor(\.measurementStartedAt)])
            ).map(\.snapshot)
            let events = try container.mainContext.fetch(
                FetchDescriptor<RetentionEvent>(sortBy: [SortDescriptor(\.occurredAt)])
            ).map(\.snapshot)
            guard let reportingWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
                logger.error("Failed to write retention baseline at calendar-week stage.")
                return
            }
            let report = RetentionReport.make(
                installations: installations,
                events: events,
                asOf: now,
                calendar: calendar,
                reportingWeek: reportingWeek
            )
            try store.save(report)

            do {
                let assignments = try container.mainContext.fetch(
                    FetchDescriptor<ExperimentAssignment>(sortBy: [SortDescriptor(\.assignedAt)])
                ).map(\.snapshot)
                let cohortAssignments = assignments.filter {
                    $0.experimentKey == OnboardingExperiment.key && $0.assignedAt < now
                }
                guard let cohortStart = cohortAssignments.first?.assignedAt else { return }
                let experimentReport = OnboardingExperimentReport.make(
                    assignments: assignments,
                    installations: installations,
                    events: events,
                    asOf: now,
                    calendar: calendar,
                    cohort: DateInterval(start: cohortStart, end: now)
                )
                try onboardingStore.save(experimentReport)
            } catch {
                logger.error("Failed to write onboarding experiment report: \(String(describing: error), privacy: .public)")
            }
        } catch {
            logger.error("Failed to write retention baseline: \(String(describing: error), privacy: .public)")
        }
    }
}
