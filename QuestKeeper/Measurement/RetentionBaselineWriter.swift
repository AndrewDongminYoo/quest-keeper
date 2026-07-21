import Foundation
import OSLog
import SwiftData

@MainActor
final class RetentionBaselineWriter {
    private let store: RetentionBaselineStore
    private let logger = Logger(
        subsystem: "kr.donminzzi.QuestKeeper",
        category: "RetentionMeasurement"
    )

    init(store: RetentionBaselineStore = RetentionBaselineStore()) {
        self.store = store
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
        } catch {
            logger.error("Failed to write retention baseline: \(String(describing: error), privacy: .public)")
        }
    }
}
